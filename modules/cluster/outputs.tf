output "cluster_id" {
  description = "ID of created kafka cluster"
  value       = confluent_kafka_cluster.cluster.id
}

output "kafka_cluster_url" {
  description = "URL of the kafka cluster (bootstrap server without SASL_SSL:// prefix)"
  value       = local.gcp_kafka_secrets["kafka_cluster_api_key_${local.cluster_type_suffix}"] != null ? replace(confluent_kafka_cluster.cluster.bootstrap_endpoint, "SASL_SSL://", "") : null
}

output "kafka_cluster_api_key" {
  description = "API Key/Secret for the Kafka cluster"
  value = {
    "key"    = confluent_api_key.api_key.id
    "secret" = confluent_api_key.api_key.secret
  }
  sensitive = true
}

output "rest_endpoint" {
  description = "REST endpoint of the Kafka cluster"
  value       = confluent_kafka_cluster.cluster.rest_endpoint
}

output "bootstrap_endpoint" {
  description = "Bootstrap endpoint of the Kafka cluster"
  value       = confluent_kafka_cluster.cluster.bootstrap_endpoint
}

# SSH tunnel instruction outputs (for bastion host)
output "bastion_ssh_tunnel_instructions" {
  description = "Instructions for using SSH tunnel to access private Confluent cluster."
  value = var.bastion_enabled && var.platt_enabled ? (<<-EOF

=== SSH Tunnel for Local Development ===

1. Start the SSH tunnel on port 443 (requires sudo):

   sudo gcloud compute ssh ${var.bastion_instance_name} \
     --zone=${var.bastion_zone} \
     --project=${var.platt_gcp_project} \
     --tunnel-through-iap \
     -- -L 443:${var.platt_endpoint_ip}:443 -N

2. Add DNS entry to /etc/hosts for your cluster:

   echo "127.0.0.1 ${confluent_kafka_cluster.cluster.id}.${var.platt_dns_domain}" | sudo tee -a /etc/hosts

3. Run Terraform with the tunnel active.

=== Alternative: Direct SSH using bastion public IP ===

   sudo ssh -L 443:${var.platt_endpoint_ip}:443 -N <user>@<bastion_public_ip>

EOF
  ) : null
}

output "bastion_github_actions_workflow" {
  description = "GitHub Actions workflow steps for SSH tunneling via bastion."
  value = var.bastion_enabled && var.platt_enabled ? (<<-EOF

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
    sudo gcloud compute ssh ${var.bastion_instance_name} \
      --zone=${var.bastion_zone} \
      --project=${var.platt_gcp_project} \
      --tunnel-through-iap \
      -- -L 443:${var.platt_endpoint_ip}:443 -N -f

    # Add DNS entry for the cluster
    echo "127.0.0.1 ${confluent_kafka_cluster.cluster.id}.${var.platt_dns_domain}" | sudo tee -a /etc/hosts

- name: Run Terraform (with tunnel active)
  run: |
    terragrunt apply -auto-approve

EOF
  ) : null
}
