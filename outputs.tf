output "kafka_url" {
  description = "URL of the kafka cluster"
  value       = local.bootstrap_servers
}

output api_key {
  description = "API Key/Secret for the Kafka cluster"
  value = {
    "key"    = confluentcloud_api_key.api_key.key
    "secret" = confluentcloud_api_key.api_key.secret
  }
  sensitive = true
}

output "service_account_ids" {
  description = "Map of service account IDs"
  value       = {
    for key in toset(var.service_accounts):
      key => confluentcloud_service_account.service_account[key].id
  }
}

output "service_account_api_keys" {
  description = "Map of API Keys/Secrets for the service accounts"
  value = {
    for key in toset(var.service_accounts):
      key => {
        "key"    = confluentcloud_api_key.service_account_api_key[key].key
        "secret" = confluentcloud_api_key.service_account_api_key[key].secret
      }
  }
  sensitive = true
}