locals {
  # Default zones for Private Service Connect based on region
  psc_zones = var.private_service_connect.enabled ? coalesce(
    var.private_service_connect.zones,
    ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
  ) : []

  # Private Link Attachment (PLATT) configuration
  platt_enabled     = var.private_link_attachment.enabled
  platt_gcp_project = local.platt_enabled ? coalesce(var.private_link_attachment.gcp_project, var.project_id) : null
  platt_name        = local.platt_enabled ? coalesce(var.private_link_attachment.name, "${var.name}-platt") : null
  platt_dns_domain  = local.platt_enabled ? "${var.region}.gcp.private.confluent.cloud" : null

  gcp_kafka_secrets = {
    kafka_cluster_api_key          = confluent_api_key.api_key.id
    kafka_cluster_api_secret       = confluent_api_key.api_key.secret
    kafka_cluster_bootstrap_server = replace(confluent_kafka_cluster.cluster.bootstrap_endpoint, "SASL_SSL://", "")
    kafka_schema_registry_key      = confluent_api_key.registry_api_key.id
    kafka_schema_registry_secret   = confluent_api_key.registry_api_key.secret
    kafka_schema_registry_url      = data.confluent_schema_registry_cluster.registry.rest_endpoint

    spring_cloud_stream_kafka_binder_brokers                     = confluent_kafka_cluster.cluster.bootstrap_endpoint
    spring_kafka_properties_sasl_jaas_config                     = "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${confluent_api_key.api_key.id}\" password=\"${confluent_api_key.api_key.secret}\";"
    spring_kafka_properties_schema_registry_basic_auth_user_info = "${confluent_api_key.registry_api_key.id}:${confluent_api_key.registry_api_key.secret}"
  }
}

data "google_secret_manager_secret_version" "confluent_secrets" {
  for_each = (var.confluent_auth_project != "") ? toset(var.confluent_secrets) : []
  project  = var.confluent_auth_project
  secret   = each.key
}

provider "confluent" {
  cloud_api_key    = (var.confluent_auth_project != "") ? data.google_secret_manager_secret_version.confluent_secrets["tf-confluent-api-key"].secret_data : var.confluent_secrets[0]
  cloud_api_secret = (var.confluent_auth_project != "") ? data.google_secret_manager_secret_version.confluent_secrets["tf-confluent-api-secret"].secret_data : var.confluent_secrets[1]
}

resource "confluent_environment" "environment" {
  display_name = var.environment

  lifecycle {
    prevent_destroy = true
  }
}

# Private Service Connect Network (only created when PSC is enabled)
resource "confluent_network" "private_service_connect" {
  count = var.private_service_connect.enabled ? 1 : 0

  display_name     = coalesce(var.private_service_connect.network_name, "${var.name}-psc-network")
  cloud            = "GCP"
  region           = var.region
  connection_types = ["PRIVATELINK"]
  zones            = local.psc_zones

  environment {
    id = confluent_environment.environment.id
  }

  dns_config {
    resolution = "PRIVATE"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Private Link Access - allows GCP project to connect via Private Service Connect
resource "confluent_private_link_access" "gcp" {
  count = var.private_service_connect.enabled ? 1 : 0

  display_name = "${var.name}-psc-access"

  gcp {
    project = var.private_service_connect.gcp_project_id
  }

  environment {
    id = confluent_environment.environment.id
  }

  network {
    id = confluent_network.private_service_connect[0].id
  }
}

# =============================================================================
# Private Link Attachment (PLATT) - for Enterprise/serverless clusters
# =============================================================================

# Private Link Attachment - reservation in Confluent Cloud
resource "confluent_private_link_attachment" "platt" {
  count = local.platt_enabled ? 1 : 0

  cloud        = "GCP"
  region       = var.region
  display_name = local.platt_name

  environment {
    id = confluent_environment.environment.id
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Static internal IP for PSC endpoint
resource "google_compute_address" "platt" {
  count = local.platt_enabled ? 1 : 0

  name         = "${local.platt_name}-endpoint-ip"
  project      = local.platt_gcp_project
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.private_link_attachment.subnetwork
  address      = var.private_link_attachment.ip_address
}

# PSC endpoint - connects to Confluent's service attachment
resource "google_compute_forwarding_rule" "platt" {
  count = local.platt_enabled ? 1 : 0

  name    = "${local.platt_name}-endpoint"
  project = local.platt_gcp_project
  region  = var.region

  target                = confluent_private_link_attachment.platt[0].gcp[0].private_service_connect_service_attachment
  load_balancing_scheme = ""
  network               = var.private_link_attachment.network
  ip_address            = google_compute_address.platt[0].id
}

# Registers the GCP PSC endpoint with Confluent
resource "confluent_private_link_attachment_connection" "platt" {
  count = local.platt_enabled ? 1 : 0

  display_name = "${local.platt_name}-connection"

  environment {
    id = confluent_environment.environment.id
  }

  gcp {
    private_service_connect_connection_id = google_compute_forwarding_rule.platt[0].psc_connection_id
  }

  private_link_attachment {
    id = confluent_private_link_attachment.platt[0].id
  }
}

# Private DNS zone for Confluent private endpoints
resource "google_dns_managed_zone" "platt" {
  count = local.platt_enabled ? 1 : 0

  name        = replace(local.platt_dns_domain, ".", "-")
  project     = local.platt_gcp_project
  dns_name    = "${local.platt_dns_domain}."
  description = "Private DNS zone for Confluent Cloud Private Link Attachment"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.private_link_attachment.network
    }
  }
}

# Wildcard A record pointing all subdomains to the PSC endpoint IP
resource "google_dns_record_set" "platt_wildcard" {
  count = local.platt_enabled ? 1 : 0

  name         = "*.${google_dns_managed_zone.platt[0].dns_name}"
  project      = local.platt_gcp_project
  managed_zone = google_dns_managed_zone.platt[0].name
  type         = "A"
  ttl          = 60

  rrdatas = [google_compute_address.platt[0].address]
}

resource "confluent_kafka_cluster" "cluster" {
  display_name = var.name
  cloud        = "GCP"
  region       = var.region
  # Private Service Connect requires MULTI_ZONE availability
  availability = var.private_service_connect.enabled ? "MULTI_ZONE" : var.availability

  environment {
    id = confluent_environment.environment.id
  }

  # Network reference for Private Service Connect
  dynamic "network" {
    for_each = var.private_service_connect.enabled ? [1] : []
    content {
      id = confluent_network.private_service_connect[0].id
    }
  }

  # Cluster type blocks - exactly one will be created based on var.cluster_type
  dynamic "basic" {
    for_each = var.cluster_type == "basic" ? [1] : []
    content {}
  }
  dynamic "standard" {
    for_each = var.cluster_type == "standard" ? [1] : []
    content {}
  }
  dynamic "enterprise" {
    for_each = var.cluster_type == "enterprise" ? [1] : []
    content {}
  }
  dynamic "dedicated" {
    for_each = var.cluster_type == "dedicated" ? [1] : []
    content {
      cku = var.dedicated_cku
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [confluent_private_link_access.gcp]
}

resource "confluent_api_key" "api_key" {
  display_name = "Terraform Runner API key"
  description  = "Created by Terraform"
  owner {
    id          = var.terraform_runner_user_id
    api_version = "iam/v2"
    kind        = "User"
  }

  managed_resource {
    id          = confluent_kafka_cluster.cluster.id
    api_version = confluent_kafka_cluster.cluster.api_version
    kind        = confluent_kafka_cluster.cluster.kind

    environment {
      id = confluent_environment.environment.id
    }
  }
}

# Schema Registry is auto-provisioned with environments in provider v2.0+
# Use data source to reference the existing Schema Registry cluster
data "confluent_schema_registry_cluster" "registry" {
  environment {
    id = confluent_environment.environment.id
  }

  depends_on = [confluent_kafka_cluster.cluster]
}

resource "confluent_api_key" "registry_api_key" {
  display_name = "Registry API key"
  description  = "Created by Terraform"
  owner {
    id          = var.terraform_runner_user_id
    api_version = "iam/v2"
    kind        = "User"
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.registry.id
    api_version = data.confluent_schema_registry_cluster.registry.api_version
    kind        = data.confluent_schema_registry_cluster.registry.kind

    environment {
      id = confluent_environment.environment.id
    }
  }
}

resource "google_secret_manager_secret" "kafka_secret_id" {
  for_each = local.gcp_kafka_secrets

  secret_id = each.key

  labels = {
    terraform = ""
  }

  replication {
    automatic = true
  }
  project = var.project_id
}

resource "google_secret_manager_secret_version" "kafka_secret_value" {
  for_each = local.gcp_kafka_secrets

  secret      = google_secret_manager_secret.kafka_secret_id[each.key].id
  secret_data = each.value
}
