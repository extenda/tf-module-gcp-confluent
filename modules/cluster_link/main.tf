locals {
  cluster_link_enabled = var.cluster_link.enabled
  cluster_link_name    = local.cluster_link_enabled ? coalesce(var.cluster_link.link_name, "${var.cluster_name}-link") : null
  cluster_link_topics  = local.cluster_link_enabled ? var.cluster_link.mirror_topics : []

  # When local_rest_endpoint_port is set, use localhost with custom port for SSH tunnel access
  cluster_rest_endpoint = var.cluster_link.local_rest_endpoint_port != null ? (
    "https://${var.destination_cluster_id}.${var.region}.gcp.private.confluent.cloud:${var.cluster_link.local_rest_endpoint_port}"
  ) : var.destination_cluster_rest_endpoint
}

# =============================================================================
# Cluster Link - for replicating data from an existing source cluster
# =============================================================================

# Cluster Link - destination-initiated link from source cluster
# Requires connectivity to the destination cluster's REST endpoint (e.g., via SSH tunnel for private clusters)
resource "confluent_cluster_link" "link" {
  count = local.cluster_link_enabled ? 1 : 0

  link_name = local.cluster_link_name
  link_mode = "DESTINATION"

  # Source cluster - the cluster to replicate from
  source_kafka_cluster {
    id                 = var.cluster_link.source_cluster_id
    bootstrap_endpoint = var.cluster_link.source_bootstrap_endpoint
    credentials {
      key    = var.source_cluster_api_key
      secret = var.source_cluster_api_secret
    }
  }

  # Destination cluster - the enterprise cluster (this cluster)
  destination_kafka_cluster {
    id            = var.destination_cluster_id
    rest_endpoint = local.cluster_rest_endpoint
    credentials {
      key    = var.destination_cluster_api_key
      secret = var.destination_cluster_api_secret
    }
  }

  config = var.cluster_link.config

  lifecycle {
    ignore_changes = [
      destination_kafka_cluster[0].rest_endpoint
    ]
  }
}

# Mirror Topics - replicate specified topics from source cluster
resource "confluent_kafka_mirror_topic" "mirror" {
  for_each = toset(local.cluster_link_topics)

  source_kafka_topic {
    topic_name = each.value
  }

  cluster_link {
    link_name = confluent_cluster_link.link[0].link_name
  }

  kafka_cluster {
    id            = var.destination_cluster_id
    rest_endpoint = local.cluster_rest_endpoint
    credentials {
      key    = var.destination_cluster_api_key
      secret = var.destination_cluster_api_secret
    }
  }

  lifecycle {
    ignore_changes = [
      kafka_cluster[0].rest_endpoint
    ]
  }
}
