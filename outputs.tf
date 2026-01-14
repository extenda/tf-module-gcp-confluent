output "kafka_cluster_url" {
  description = "URL of the kafka cluster"
  value       = local.gcp_kafka_secrets["kafka_cluster_bootstrap_server_${local.cluster_type_suffix}"]
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
  description = "ID of the Confluent environment"
  value       = local.environment_id
}

output "cluster_id" {
  description = "ID of created kafka cluster"
  value       = confluent_kafka_cluster.cluster.id
}

# Private Service Connect outputs (for dedicated clusters)
output "private_service_connect" {
  description = "Private Service Connect configuration. Use service_attachments to create GCP Private Service Connect endpoints."
  value = var.private_service_connect.enabled ? {
    network_id          = confluent_network.private_service_connect[0].id
    dns_domain          = confluent_network.private_service_connect[0].dns_domain
    service_attachments = confluent_network.private_service_connect[0].gcp[0].private_service_connect_service_attachments
  } : null
}

# Private Link Attachment outputs (for Enterprise/serverless clusters)
output "private_link_attachment" {
  description = "Private Link Attachment (PLATT) configuration for Enterprise/serverless clusters."
  value = local.platt_enabled ? {
    attachment_id              = confluent_private_link_attachment.platt[0].id
    attachment_display_name    = confluent_private_link_attachment.platt[0].display_name
    connection_id              = confluent_private_link_attachment_connection.platt[0].id
    service_attachment_uri     = confluent_private_link_attachment.platt[0].gcp[0].private_service_connect_service_attachment
    endpoint_ip                = google_compute_address.platt[0].address
    endpoint_name              = google_compute_forwarding_rule.platt[0].name
    endpoint_psc_connection_id = google_compute_forwarding_rule.platt[0].psc_connection_id
    dns_zone_name              = google_dns_managed_zone.platt[0].name
    dns_domain                 = local.platt_dns_domain
  } : null
}
