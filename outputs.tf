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
  value = confluent_environment.environment.id
}

output "cluster_id" {
  description = "ID of created kafka cluster"
  value = confluent_kafka_cluster.cluster.id
}
