variable "cluster_link" {
  type = object({
    enabled                      = bool
    link_name                    = optional(string)
    source_cluster_id            = optional(string)
    source_bootstrap_endpoint    = optional(string)
    source_api_key               = optional(string)
    source_api_secret            = optional(string)
    mirror_topics                = optional(list(string), [])
    local_rest_endpoint_port     = optional(number)
    acl_sync_enabled             = optional(bool, false)
    consumer_offset_sync_enabled = optional(bool, false)
  })
  description = <<-EOT
    Cluster Link configuration for replicating data from an existing source cluster.
    Creates a destination-initiated cluster link where this cluster receives data from the source.
    Requires connectivity to this cluster's REST endpoint (e.g., via SSH tunnel for private clusters).

    - enabled: Whether to create the cluster link
    - link_name: Name for the cluster link (defaults to "<cluster_name>-link")
    - source_cluster_id: ID of the source Kafka cluster (e.g., "lkc-abc123")
    - source_bootstrap_endpoint: Bootstrap endpoint of the source cluster (e.g., "pkc-xxxxx.region.gcp.confluent.cloud:9092")
    - source_api_key: API key for authenticating to the source cluster
    - source_api_secret: API secret for authenticating to the source cluster
    - mirror_topics: List of topic names to create as mirror topics (optional)
    - local_rest_endpoint_port: Local port for SSH tunnel to REST endpoint (e.g., 8443). When set, uses localhost:<port> instead of the private endpoint.
    - acl_sync_enabled: Whether to sync ACLs from source to destination cluster (default: false)
    - consumer_offset_sync_enabled: Whether to sync consumer offsets from source to destination cluster (default: false)
  EOT
  default = {
    enabled = false
  }
  sensitive = true

  validation {
    condition     = !var.cluster_link.enabled || var.cluster_link.source_cluster_id != null
    error_message = "source_cluster_id is required when cluster_link is enabled"
  }

  validation {
    condition     = !var.cluster_link.enabled || var.cluster_link.source_bootstrap_endpoint != null
    error_message = "source_bootstrap_endpoint is required when cluster_link is enabled"
  }

  validation {
    condition     = !var.cluster_link.enabled || var.cluster_link.source_api_key != null
    error_message = "source_api_key is required when cluster_link is enabled"
  }

  validation {
    condition     = !var.cluster_link.enabled || var.cluster_link.source_api_secret != null
    error_message = "source_api_secret is required when cluster_link is enabled"
  }
}

# =============================================================================
# Destination Cluster Variables (from cluster module)
# =============================================================================

variable "destination_cluster_id" {
  description = "ID of the destination Kafka cluster"
  type        = string
}

variable "destination_cluster_rest_endpoint" {
  description = "REST endpoint of the destination Kafka cluster"
  type        = string
}

variable "destination_cluster_api_key" {
  description = "API key for the destination Kafka cluster"
  type        = string
  sensitive   = true
}

variable "destination_cluster_api_secret" {
  description = "API secret for the destination Kafka cluster"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the cluster (used for default link name)"
  type        = string
}

variable "region" {
  description = "Region of the cluster (used for private endpoint URL construction)"
  type        = string
}
