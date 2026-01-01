output "kafka_cluster_url" {
  description = "URL of the kafka cluster"
  value       = local.gcp_kafka_secrets.kafka_cluster_bootstrap_server
}

output "kafka_cluster_api_key" {
  description = "API Key/Secret for the Kafka cluster"
  value = {
    "key"    = confluent_api_key.api_key.id
    "secret" = confluent_api_key.api_key.secret
  }
  sensitive = true
}

output "environment_id" {
  description = "ID of created confluent environment"
  value       = confluent_environment.environment.id
}

output "cluster_id" {
  description = "ID of created kafka cluster"
  value       = confluent_kafka_cluster.cluster.id
}

# Private Service Connect outputs
output "private_service_connect" {
  description = "Private Service Connect configuration. Use service_attachments to create GCP Private Service Connect endpoints."
  value = var.private_service_connect.enabled ? {
    network_id          = confluent_network.private_service_connect[0].id
    dns_domain          = confluent_network.private_service_connect[0].dns_domain
    service_attachments = confluent_network.private_service_connect[0].gcp[0].private_service_connect_service_attachments
  } : null
}
