locals {
  # Environment ID - use existing or created
  environment_id = var.create_environment ? confluent_environment.environment[0].id : var.environment_id

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

  # Bastion host configuration
  bastion_enabled = var.bastion_host.enabled
  bastion_zone    = local.bastion_enabled ? coalesce(var.bastion_host.zone, "${var.region}-b") : null
}

# =============================================================================
# Confluent Environment
# =============================================================================

resource "confluent_environment" "environment" {
  count        = var.create_environment ? 1 : 0
  display_name = var.environment

  lifecycle {
    prevent_destroy = false
  }
}

# =============================================================================
# Private Service Connect Network (for Dedicated clusters)
# =============================================================================

resource "confluent_network" "private_service_connect" {
  count = var.private_service_connect.enabled ? 1 : 0

  display_name     = coalesce(var.private_service_connect.network_name, "${var.name}-psc-network")
  cloud            = "GCP"
  region           = var.region
  connection_types = ["PRIVATELINK"]
  zones            = local.psc_zones

  environment {
    id = local.environment_id
  }

  dns_config {
    resolution = "PRIVATE"
  }

  lifecycle {
    prevent_destroy = false
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
    id = local.environment_id
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
    id = local.environment_id
  }

  lifecycle {
    prevent_destroy = false
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
    id = local.environment_id
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

# =============================================================================
# Bastion Host - for SSH tunneling to private Confluent clusters
# =============================================================================

# Service account for Bastion VM
resource "google_service_account" "bastion" {
  count        = local.bastion_enabled ? 1 : 0
  project      = var.project_id
  account_id   = substr("${var.name}-bastion", 0, 30)
  display_name = "Bastion host for ${var.name}"
}

# Firewall rule to allow SSH traffic
resource "google_compute_firewall" "bastion_ssh" {
  count   = local.bastion_enabled ? 1 : 0
  name    = "${var.name}-bastion-ssh"
  project = local.platt_gcp_project
  network = var.private_link_attachment.network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.bastion_host.allowed_cidrs
  target_tags   = ["bastion"]
}

# Bastion VM instance
resource "google_compute_instance" "bastion" {
  count        = local.bastion_enabled ? 1 : 0
  name         = "${var.name}-bastion"
  project      = local.platt_gcp_project
  zone         = local.bastion_zone
  machine_type = var.bastion_host.machine_type

  tags = ["bastion"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = var.private_link_attachment.subnetwork
    access_config {
      # Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.bastion[0].email
    scopes = ["cloud-platform"]
  }

  # Enable OS Login for SSH key management via IAM
  metadata = {
    enable-oslogin = "TRUE"
  }
}

# =============================================================================
# Schema Registry - auto-provisioned with environments in provider v2.0+
# =============================================================================

# Use data source to reference the existing Schema Registry cluster
# Only created when creating a new environment
data "confluent_schema_registry_cluster" "registry" {
  count = var.create_environment ? 1 : 0

  environment {
    id = local.environment_id
  }
}

# Service Account for Schema Registry access - only created when creating a new environment
resource "confluent_service_account" "schema_registry" {
  count = var.create_environment ? 1 : 0

  display_name = "${var.name}-schema-registry-sa"
  description  = "Service account for ${var.name} Schema Registry access"
}

# Grant the service account ResourceOwner role on the Schema Registry
resource "confluent_role_binding" "schema_registry_resource_owner" {
  count = var.create_environment ? 1 : 0

  principal   = "User:${confluent_service_account.schema_registry[0].id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${data.confluent_schema_registry_cluster.registry[0].resource_name}/subject=*"
}

# Schema Registry API key - only created when creating a new environment
resource "confluent_api_key" "registry_api_key" {
  count = var.create_environment ? 1 : 0

  display_name = "${var.name} Schema Registry API key"
  description  = "API key for ${var.name} Schema Registry access"

  # Skip API key verification - required when cluster uses private networking
  # and Terraform cannot reach the private endpoint
  disable_wait_for_ready = true

  owner {
    id          = confluent_service_account.schema_registry[0].id
    api_version = confluent_service_account.schema_registry[0].api_version
    kind        = confluent_service_account.schema_registry[0].kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.registry[0].id
    api_version = data.confluent_schema_registry_cluster.registry[0].api_version
    kind        = data.confluent_schema_registry_cluster.registry[0].kind

    environment {
      id = local.environment_id
    }
  }

  depends_on = [confluent_role_binding.schema_registry_resource_owner]
}
