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

output "rest_endpoint" {
  description = "REST endpoint of the Kafka cluster"
  value       = confluent_kafka_cluster.cluster.rest_endpoint
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

# Cluster Link outputs
output "cluster_link" {
  description = "Cluster Link configuration for data replication from source cluster."
  value = local.cluster_link_enabled ? {
    link_name         = confluent_cluster_link.link[0].link_name
    link_mode         = confluent_cluster_link.link[0].link_mode
    source_cluster_id = var.cluster_link.source_cluster_id
    mirror_topics     = local.cluster_link_topics
  } : null
  sensitive = true
}

# Bastion Host outputs
output "bastion_host_public_ip" {
  description = "Public IP address of the bastion host for SSH access."
  value       = local.bastion_enabled ? google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip : null
}

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

output "bastion_ssh_tunnel_instructions" {
  description = "Instructions for using SSH tunnel to access private Confluent cluster."
  value = local.bastion_enabled && local.platt_enabled ? (<<-EOF

=== SSH Tunnel for Local Development ===

1. Start the SSH tunnel on port 443 (requires sudo):

   sudo gcloud compute ssh ${google_compute_instance.bastion[0].name} \
     --zone=${local.bastion_zone} \
     --project=${local.platt_gcp_project} \
     --tunnel-through-iap \
     -- -L 443:${google_compute_address.platt[0].address}:443 -N

2. Add DNS entry to /etc/hosts for your cluster:

   echo "127.0.0.1 ${confluent_kafka_cluster.cluster.id}.${local.platt_dns_domain}" | sudo tee -a /etc/hosts

3. Run Terraform with the tunnel active.

=== Alternative: Direct SSH using bastion public IP ===

   sudo ssh -L 443:${google_compute_address.platt[0].address}:443 -N <user>@<bastion_public_ip>

EOF
  ) : null
}

output "bastion_github_actions_workflow" {
  description = "GitHub Actions workflow steps for SSH tunneling via bastion."
  value = local.bastion_enabled && local.platt_enabled ? (<<-EOF

=== GitHub Actions Workflow ===

1. Set up Workload Identity Federation for your GitHub repository to authenticate with GCP.
   See: https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines

2. Grant the GitHub Actions service account the following roles:
   - roles/compute.instanceAdmin.v1 (or roles/compute.osLogin for OS Login)
   - roles/iap.tunnelResourceAccessor (for IAP tunnel)

3. Add these steps to your workflow:

- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID'
    service_account: 'SA_EMAIL'

- name: Set up SSH tunnel via IAP
  run: |
    sudo gcloud compute ssh ${google_compute_instance.bastion[0].name} \
      --zone=${local.bastion_zone} \
      --project=${local.platt_gcp_project} \
      --tunnel-through-iap \
      -- -L 443:${google_compute_address.platt[0].address}:443 -N -f

    # Add DNS entry for the cluster
    echo "127.0.0.1 ${confluent_kafka_cluster.cluster.id}.${local.platt_dns_domain}" | sudo tee -a /etc/hosts

- name: Run Terraform (with tunnel active)
  run: |
    terragrunt apply -auto-approve

EOF
  ) : null
}
