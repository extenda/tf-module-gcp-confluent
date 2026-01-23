# =============================================================================
# Environment Outputs
# =============================================================================

output "environment_id" {
  description = "ID of the Confluent environment"
  value       = module.network.environment_id
}

# =============================================================================
# Cluster Outputs
# =============================================================================

output "cluster_id" {
  description = "ID of created kafka cluster"
  value       = module.cluster.cluster_id
}

output "kafka_cluster_url" {
  description = "URL of the kafka cluster"
  value       = module.cluster.kafka_cluster_url
}

output "kafka_cluster_api_key" {
  description = "API Key/Secret for the Kafka cluster"
  value       = module.cluster.kafka_cluster_api_key
  sensitive   = true
}

output "rest_endpoint" {
  description = "REST endpoint of the Kafka cluster"
  value       = module.cluster.rest_endpoint
}

# =============================================================================
# Private Networking Outputs
# =============================================================================

# Private Service Connect outputs (for dedicated clusters)
output "private_service_connect" {
  description = "Private Service Connect configuration. Use service_attachments to create GCP Private Service Connect endpoints."
  value       = module.network.private_service_connect
}

# Private Link Attachment outputs (for Enterprise/serverless clusters)
output "private_link_attachment" {
  description = "Private Link Attachment (PLATT) configuration for Enterprise/serverless clusters."
  value       = module.network.private_link_attachment
}

# =============================================================================
# Bastion Host Outputs
# =============================================================================

output "bastion_host_public_ip" {
  description = "Public IP address of the bastion host for SSH access."
  value       = module.network.bastion_host != null ? module.network.bastion_host.public_ip : null
}

output "bastion_host" {
  description = "Bastion host configuration for SSH tunneling to private Confluent clusters."
  value       = module.network.bastion_host
}

output "bastion_ssh_tunnel_instructions" {
  description = "Instructions for using SSH tunnel to access private Confluent cluster."
  value       = module.cluster.bastion_ssh_tunnel_instructions
}

output "bastion_github_actions_workflow" {
  description = "GitHub Actions workflow steps for SSH tunneling via bastion."
  value       = module.cluster.bastion_github_actions_workflow
}

# =============================================================================
# Cluster Link Outputs
# =============================================================================

output "cluster_link" {
  description = "Cluster Link configuration for data replication from source cluster."
  value       = module.cluster.cluster_link
  sensitive   = true
}

# =============================================================================
# Schema Registry Outputs
# =============================================================================

output "schema_registry" {
  description = "Schema Registry API key/secret/URL. Only populated when create_environment is true."
  value       = module.network.schema_registry
  sensitive   = true
}
