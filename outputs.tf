output "kafka_url" {
  description = "URL of the kafka cluster"
  value       = local.bootstrap_servers
}

output "key" {
  description = "API Key for the Kafka cluster"
  value       = confluentcloud_api_key.api_key.key
  sensitive   = true
}

output "secret" {
  description = "API Secret for the Kafka cluster"
  value       = confluentcloud_api_key.api_key.secret
  sensitive   = true
}
