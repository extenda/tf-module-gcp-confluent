locals {
  # Include cluster_type in secret names to avoid collisions when multiple clusters exist
  cluster_type_suffix = var.cluster_type

  # Base Kafka secrets (always created)
  gcp_kafka_secrets_base = {
    "kafka_cluster_api_key_${local.cluster_type_suffix}"          = confluent_api_key.api_key.id
    "kafka_cluster_api_secret_${local.cluster_type_suffix}"       = confluent_api_key.api_key.secret
    "kafka_cluster_bootstrap_server_${local.cluster_type_suffix}" = replace(confluent_kafka_cluster.cluster.bootstrap_endpoint, "SASL_SSL://", "")

    "spring_cloud_stream_kafka_binder_brokers_${local.cluster_type_suffix}" = confluent_kafka_cluster.cluster.bootstrap_endpoint
    "spring_kafka_properties_sasl_jaas_config_${local.cluster_type_suffix}" = "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${confluent_api_key.api_key.id}\" password=\"${confluent_api_key.api_key.secret}\";"
  }

  # Schema Registry secrets (only when schema_registry credentials are provided)
  gcp_kafka_secrets_registry = var.schema_registry != null ? {
    "kafka_schema_registry_key_${local.cluster_type_suffix}"                                    = var.schema_registry.api_key
    "kafka_schema_registry_secret_${local.cluster_type_suffix}"                                 = var.schema_registry.api_secret
    "kafka_schema_registry_url_${local.cluster_type_suffix}"                                    = var.schema_registry.rest_endpoint
    "spring_kafka_properties_schema_registry_basic_auth_user_info_${local.cluster_type_suffix}" = "${var.schema_registry.api_key}:${var.schema_registry.api_secret}"
  } : {}

  gcp_kafka_secrets = merge(local.gcp_kafka_secrets_base, local.gcp_kafka_secrets_registry)

}

# =============================================================================
# Kafka Cluster
# =============================================================================

resource "confluent_kafka_cluster" "cluster" {
  display_name = var.name
  cloud        = "GCP"
  region       = var.region
  # Private Service Connect requires MULTI_ZONE availability
  availability = var.use_private_service_connect ? "MULTI_ZONE" : var.availability

  environment {
    id = var.environment_id
  }

  # Network reference for Private Service Connect
  dynamic "network" {
    for_each = var.network_id != null ? [1] : []
    content {
      id = var.network_id
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
    prevent_destroy = false
  }
}

# =============================================================================
# Kafka Service Account and API Key
# =============================================================================

# Service Account for Kafka cluster access
resource "confluent_service_account" "kafka" {
  display_name = "${var.name}-kafka-sa"
  description  = "Service account for ${var.name} Kafka cluster access"
}

# Grant the service account CloudClusterAdmin role on the Kafka cluster
resource "confluent_role_binding" "kafka_cluster_admin" {
  principal   = "User:${confluent_service_account.kafka.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.cluster.rbac_crn
}

resource "confluent_api_key" "api_key" {
  display_name = "${var.name} Kafka API key"
  description  = "API key for ${var.name} Kafka cluster access"

  # Skip API key verification - required when cluster uses private networking
  # and Terraform cannot reach the private endpoint
  disable_wait_for_ready = true

  owner {
    id          = confluent_service_account.kafka.id
    api_version = confluent_service_account.kafka.api_version
    kind        = confluent_service_account.kafka.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.cluster.id
    api_version = confluent_kafka_cluster.cluster.api_version
    kind        = confluent_kafka_cluster.cluster.kind

    environment {
      id = var.environment_id
    }
  }

  depends_on = [confluent_role_binding.kafka_cluster_admin]
}

# =============================================================================
# GCP Secret Manager - Store Kafka Credentials
# =============================================================================

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

