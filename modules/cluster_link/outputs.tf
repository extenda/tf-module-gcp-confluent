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
