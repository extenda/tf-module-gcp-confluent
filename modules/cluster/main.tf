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

  # =============================================================================
  # RBAC Locals - Group Mappings and Role Bindings
  # =============================================================================

  # Map of group mapping names to their resources for lookup
  group_mapping_ids = {
    for gm in var.group_mappings : gm.name => confluent_group_mapping.mappings[gm.name].id
  }

  # Role bindings that need new service accounts
  role_bindings_with_new_sa = {
    for idx, rb in var.role_bindings :
    rb.service_account.name => rb
    if rb.service_account != null
  }

  # All role bindings with resolved principals and CRN patterns
  role_bindings_resolved = {
    for idx, rb in var.role_bindings :
    "${idx}-${rb.role}-${rb.scope}" => {
      # Resolve principal from one of the three sources
      principal = (
        rb.group != null ? "User:${local.group_mapping_ids[rb.group]}" :
        rb.service_account != null ? "User:${confluent_service_account.role_binding_sa[rb.service_account.name].id}" :
        "User:${rb.principal}"
      )
      role  = rb.role
      scope = rb.scope

      # Build CRN pattern
      crn_pattern = (
        rb.crn_pattern_override != null ? rb.crn_pattern_override :
        rb.scope == "kafka" ? (
          rb.resource_type == null ? confluent_kafka_cluster.cluster.rbac_crn :
          rb.resource_type == "topic" ? "${confluent_kafka_cluster.cluster.rbac_crn}/kafka=${confluent_kafka_cluster.cluster.id}/topic=${rb.resource_pattern}" :
          rb.resource_type == "group" ? "${confluent_kafka_cluster.cluster.rbac_crn}/kafka=${confluent_kafka_cluster.cluster.id}/group=${rb.resource_pattern}" :
          rb.resource_type == "transactional-id" ? "${confluent_kafka_cluster.cluster.rbac_crn}/kafka=${confluent_kafka_cluster.cluster.id}/transactional-id=${rb.resource_pattern}" :
          confluent_kafka_cluster.cluster.rbac_crn
        ) :
        # schema-registry scope
        rb.resource_type == "subject" || rb.resource_pattern != null ? "${var.schema_registry_resource_name}/subject=${coalesce(rb.resource_pattern, "*")}" :
        var.schema_registry_resource_name
      )
    }
  }
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
    content {
      max_ecku = var.enterprise_max_ecku
    }
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

# =============================================================================
# SSO Group Mappings
# =============================================================================

resource "confluent_group_mapping" "mappings" {
  for_each = { for gm in var.group_mappings : gm.name => gm }

  display_name = each.value.name
  description  = each.value.description
  filter       = each.value.filter
}

# =============================================================================
# Custom Role Bindings - Service Accounts
# =============================================================================

# Service accounts created for role bindings
resource "confluent_service_account" "role_binding_sa" {
  for_each = local.role_bindings_with_new_sa

  display_name = "${var.name}-${each.key}"
  description  = coalesce(each.value.service_account.description, "Service account for ${each.key} on ${var.name}")
}

# =============================================================================
# Custom Role Bindings
# =============================================================================

resource "confluent_role_binding" "custom" {
  for_each = local.role_bindings_resolved

  principal   = each.value.principal
  role_name   = each.value.role
  crn_pattern = each.value.crn_pattern

  depends_on = [
    confluent_group_mapping.mappings,
    confluent_service_account.role_binding_sa
  ]
}

