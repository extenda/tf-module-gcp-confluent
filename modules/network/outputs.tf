output "environment_id" {
  description = "ID of the Confluent environment (created or passed-through)"
  value       = local.environment_id
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

# Bastion Host outputs
output "bastion_host" {
  description = "Bastion host configuration for SSH tunneling to private Confluent clusters."
  value = local.bastion_enabled ? {
    public_ip       = google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip
    instance_name   = google_compute_instance.bastion[0].name
    zone            = local.bastion_zone
    project         = local.platt_gcp_project
    psc_endpoint_ip = local.platt_enabled ? google_compute_address.platt[0].address : null
    dns_domain      = local.platt_enabled ? local.platt_dns_domain : null
  } : null
}

# Schema Registry outputs
output "schema_registry" {
  description = "Schema Registry API key/secret/URL. Only populated when create_environment is true."
  value = var.create_environment ? {
    api_key       = confluent_api_key.registry_api_key[0].id
    api_secret    = confluent_api_key.registry_api_key[0].secret
    rest_endpoint = data.confluent_schema_registry_cluster.registry[0].rest_endpoint
  } : null
  sensitive = true
}

# Internal outputs for cluster module
output "platt_dns_domain" {
  description = "DNS domain for Private Link Attachment (used by cluster module for SSH tunnel instructions)"
  value       = local.platt_dns_domain
}

output "platt_endpoint_ip" {
  description = "Private Link Attachment endpoint IP (used by cluster module for SSH tunnel instructions)"
  value       = local.platt_enabled ? google_compute_address.platt[0].address : null
}

output "platt_gcp_project" {
  description = "GCP project for Private Link Attachment resources"
  value       = local.platt_gcp_project
}

output "bastion_zone" {
  description = "Bastion host zone"
  value       = local.bastion_zone
}

output "bastion_enabled" {
  description = "Whether bastion host is enabled"
  value       = local.bastion_enabled
}

output "platt_enabled" {
  description = "Whether Private Link Attachment is enabled"
  value       = local.platt_enabled
}
