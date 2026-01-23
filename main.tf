# =============================================================================
# Root Module - Composes Network and Cluster Submodules
# =============================================================================

data "google_secret_manager_secret_version" "confluent_secrets" {
  for_each = (var.confluent_auth_project != "") ? toset(var.confluent_secrets) : []
  project  = var.confluent_auth_project
  secret   = each.key
}

provider "confluent" {
  cloud_api_key    = (var.confluent_auth_project != "") ? data.google_secret_manager_secret_version.confluent_secrets["tf-confluent-api-key"].secret_data : var.confluent_secrets[0]
  cloud_api_secret = (var.confluent_auth_project != "") ? data.google_secret_manager_secret_version.confluent_secrets["tf-confluent-api-secret"].secret_data : var.confluent_secrets[1]
}

# =============================================================================
# Network Module - Environment, Private Networking, Bastion, Schema Registry
# =============================================================================

module "network" {
  source = "./modules/network"

  environment             = var.environment
  create_environment      = var.create_environment
  environment_id          = var.environment_id
  name                    = var.name
  region                  = var.region
  project_id              = var.project_id
  private_service_connect = var.private_service_connect
  private_link_attachment = var.private_link_attachment
  bastion_host            = var.bastion_host
}

# =============================================================================
# Cluster Module - Kafka Cluster, API Keys, Secrets, Cluster Link
# =============================================================================

module "cluster" {
  source = "./modules/cluster"

  environment_id              = module.network.environment_id
  name                        = var.name
  region                      = var.region
  availability                = var.availability
  cluster_type                = var.cluster_type
  dedicated_cku               = var.dedicated_cku
  project_id                  = var.project_id
  network_id                  = module.network.private_service_connect != null ? module.network.private_service_connect.network_id : null
  use_private_service_connect = var.private_service_connect.enabled
  schema_registry             = module.network.schema_registry
  cluster_link                = var.cluster_link

  # Bastion/PLATT info for SSH tunnel instructions
  bastion_enabled       = module.network.bastion_enabled
  bastion_instance_name = module.network.bastion_host != null ? module.network.bastion_host.instance_name : null
  bastion_zone          = module.network.bastion_zone
  platt_enabled         = module.network.platt_enabled
  platt_endpoint_ip     = module.network.platt_endpoint_ip
  platt_gcp_project     = module.network.platt_gcp_project
  platt_dns_domain      = module.network.platt_dns_domain

  depends_on = [module.network]
}
