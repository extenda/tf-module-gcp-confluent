data "google_secret_manager_secret_version" "confluent_username" {
  provider = google-beta

  count   = (var.confluent_project_gcp_secret != "") ? 1 : 0
  project = var.confluent_project_gcp_secret
  secret  = var.confluent_username
}

data "google_secret_manager_secret_version" "confluent_password" {
  provider = google-beta

  count   = (var.confluent_project_gcp_secret != "") ? 1 : 0
  project = var.confluent_project_gcp_secret
  secret  = var.confluent_password
}

provider "confluentcloud" {
  username = (var.confluent_project_gcp_secret != "") ? data.google_secret_manager_secret_version.confluent_username[0].secret_data : var.confluent_username
  password = (var.confluent_project_gcp_secret != "") ? data.google_secret_manager_secret_version.confluent_password[0].secret_data : var.confluent_password
}

resource "confluentcloud_environment" "environment" {
  name = var.environment
}

resource "confluentcloud_kafka_cluster" "cluster" {
  name             = var.name
  service_provider = "gcp"
  region           = var.region
  availability     = var.availability
  environment_id   = confluentcloud_environment.environment.id
  deployment = {
    sku = var.deployment_sku
  }
  storage         = var.storage
  network_egress  = var.network_egress
  network_ingress = var.network_ingress
}

resource "confluentcloud_schema_registry" "registry" {
  environment_id   = confluentcloud_environment.environment.id
  service_provider = "gcp"
  region           = var.schema_registry_region

  depends_on       = [confluentcloud_kafka_cluster.cluster]
}

resource "confluentcloud_api_key" "api_key" {
  cluster_id     = confluentcloud_kafka_cluster.cluster.id
  environment_id = confluentcloud_environment.environment.id
}

locals {
  bootstrap_servers = [replace(confluentcloud_kafka_cluster.cluster.bootstrap_servers, "SASL_SSL://", "")]
  gcp_kafka_secrets = {
    kafka_url    = join(",", local.bootstrap_servers)
    kafka_key    = confluentcloud_api_key.api_key.key
    kafka_secret = confluentcloud_api_key.api_key.secret
  }
}


resource "google_secret_manager_secret" "kafka_secret_id" {
  provider = google-beta
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
  provider = google-beta
  for_each = local.gcp_kafka_secrets

  secret      = google_secret_manager_secret.kafka_secret_id[each.key].id
  secret_data = each.value
}
