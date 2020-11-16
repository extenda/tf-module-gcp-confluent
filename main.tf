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

resource "confluentcloud_api_key" "api_key" {
  cluster_id     = confluentcloud_kafka_cluster.cluster.id
  environment_id = confluentcloud_environment.environment.id
}

resource "confluentcloud_schema_registry" "registry" {
  environment_id   = confluentcloud_environment.environment.id
  service_provider = "gcp"
  region           = var.schema_registry_region

  depends_on = [confluentcloud_kafka_cluster.cluster]
}

resource "confluentcloud_api_key" "registry_api_key" {
  environment_id = confluentcloud_environment.environment.id
  logical_clusters = [
    confluentcloud_schema_registry.registry.id,
  ]
  description = "Created by Terraform"
}

#-------------------------------------------------------------------------------

locals {
  bootstrap_servers = [replace(confluentcloud_kafka_cluster.cluster.bootstrap_servers, "SASL_SSL://", "")]
  gcp_kafka_secrets = {
    kafka_cluster_api_key          = confluentcloud_api_key.api_key.key
    kafka_cluster_api_secret       = confluentcloud_api_key.api_key.secret
    kafka_cluster_bootstrap_server = join(",", local.bootstrap_servers)
    kafka_schema_registry_key      = confluentcloud_api_key.registry_api_key.key
    kafka_schema_registry_secret   = confluentcloud_api_key.registry_api_key.secret
    kafka_schema_registry_url      = confluentcloud_schema_registry.registry.endpoint

    spring_cloud_stream_kafka_binder_brokers = confluentcloud_kafka_cluster.cluster.bootstrap_servers
    spring_kafka_properties_sasl_jaas_config = "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${confluentcloud_api_key.api_key.key}\" password=\"${confluentcloud_api_key.api_key.secret}\";"

    spring_kafka_properties_schema_registry_basic_auth_user_info = "${confluentcloud_api_key.registry_api_key.key}:${confluentcloud_api_key.registry_api_key.secret}"
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

#-------------------------------------------------------------------------------

resource "confluentcloud_service_account" "service_account" {
  for_each    = toset(var.service_accounts)
  name        = each.key
  description = "Created by Terraform"
}

resource "confluentcloud_api_key" "service_account_api_key" {
  for_each       = toset(var.service_accounts)
  cluster_id     = confluentcloud_kafka_cluster.cluster.id
  environment_id = confluentcloud_environment.environment.id
  user_id        = confluentcloud_service_account.service_account[each.key].id
}

resource "google_secret_manager_secret" "sa_gcp_secret_key_id" {
  provider  = google-beta
  for_each  = toset(var.service_accounts)
  secret_id = "kafka_serviceaccount_${each.key}_key"

  labels = {
    terraform = ""
  }

  replication {
    automatic = true
  }
  project = var.project_id
}

resource "google_secret_manager_secret" "sa_gcp_secret_secret_id" {
  provider  = google-beta
  for_each  = toset(var.service_accounts)
  secret_id = "kafka_serviceaccount_${each.key}_secret"

  labels = {
    terraform = ""
  }

  replication {
    automatic = true
  }
  project = var.project_id
}

resource "google_secret_manager_secret_version" "sa_secret_key_value" {
  provider = google-beta
  for_each = toset(var.service_accounts)

  secret      = google_secret_manager_secret.sa_gcp_secret_key_id[each.key].id
  secret_data = confluentcloud_api_key.service_account_api_key[each.key].key
}

resource "google_secret_manager_secret_version" "sa_secret_secret_value" {
  provider = google-beta
  for_each = toset(var.service_accounts)

  secret      = google_secret_manager_secret.sa_gcp_secret_secret_id[each.key].id
  secret_data = confluentcloud_api_key.service_account_api_key[each.key].secret
}
