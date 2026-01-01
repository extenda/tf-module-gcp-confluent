locals {
  # Determine cluster type: prefer explicit cluster_type, fall back to project_env mapping
  effective_cluster_type = coalesce(
    var.cluster_type,
    var.project_env == "staging" ? "basic" : var.project_env == "prod" ? "standard" : null
  )

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

resource "confluent_kafka_cluster" "cluster" {
  display_name = var.name
  cloud        = "GCP"
  region       = var.region
  availability = var.availability
  environment {
    id = confluent_environment.environment.id
  }

  dynamic "basic" {
    for_each = local.effective_cluster_type == "basic" ? [1] : []
    content {}
  }

  dynamic "standard" {
    for_each = local.effective_cluster_type == "standard" ? [1] : []
    content {}
  }

  dynamic "enterprise" {
    for_each = local.effective_cluster_type == "enterprise" ? [1] : []
    content {}
  }

  lifecycle {
    prevent_destroy = true
  }
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
