# =============================================================================
# Authentication Variables
# =============================================================================

variable "confluent_auth_project" {
  description = "GCP project ID having secret for confluentcloud credentials"
  type        = string
  default     = "tf-admin-90301274"
}

variable "confluent_secrets" {
  description = "List of secrets to extract from Secret Manager for Auth"
  type        = list(string)
  default     = ["tf-confluent-api-key", "tf-confluent-api-secret"]
}

# =============================================================================
# Environment Variables
# =============================================================================

variable "environment" {
  description = "Confluent environment display name (used when creating a new environment)"
  type        = string
}

variable "create_environment" {
  description = "Whether to create a new Confluent environment. Set to false to use an existing environment."
  type        = bool
  default     = true
}

variable "environment_id" {
  description = "ID of an existing Confluent environment. Required when create_environment is false."
  type        = string
  default     = null
}

# =============================================================================
# Cluster Variables
# =============================================================================

variable "name" {
  description = "The name of the cluster"
  type        = string
}

variable "region" {
  description = "Region to create cluster in"
  type        = string
  default     = "europe-west1"
}

variable "availability" {
  description = "The availability zone configuration of the Kafka cluster. Accepted values are: SINGLE_ZONE and MULTI_ZONE"
  type        = string
  default     = "SINGLE_ZONE"
}

variable "cluster_type" {
  type        = string
  description = "The type of Kafka cluster. Accepted values are: basic, standard, enterprise, dedicated"

  validation {
    condition     = contains(["basic", "standard", "enterprise", "dedicated"], var.cluster_type)
    error_message = "cluster_type must be one of: basic, standard, enterprise, dedicated"
  }
}

variable "dedicated_cku" {
  type        = number
  description = "Number of CKUs for dedicated cluster. Required when cluster_type is 'dedicated'. Minimum 2 for MULTI_ZONE."
  default     = 2
}

variable "project_id" {
  description = "Project ID to add Kafka secrets"
  type        = string
}

# =============================================================================
# Private Networking Variables
# =============================================================================

variable "private_service_connect" {
  type = object({
    enabled        = bool
    gcp_project_id = optional(string)
    network_name   = optional(string)
    zones          = optional(list(string))
  })
  description = "Private Service Connect configuration. Only supported with dedicated cluster type."
  default = {
    enabled = false
  }

  validation {
    condition     = !var.private_service_connect.enabled || var.private_service_connect.gcp_project_id != null
    error_message = "gcp_project_id is required when Private Service Connect is enabled"
  }
}

variable "private_link_attachment" {
  type = object({
    enabled     = bool
    name        = optional(string)
    gcp_project = optional(string)
    network     = optional(string)
    subnetwork  = optional(string)
    ip_address  = optional(string)
  })
  description = <<-EOT
    Private Link Attachment (PLATT) configuration for Enterprise/serverless clusters.
    Creates a GCP Private Service Connect endpoint with private DNS resolution.
    This is separate from private_service_connect which is for dedicated clusters.
  EOT
  default = {
    enabled = false
  }

  validation {
    condition     = !var.private_link_attachment.enabled || var.private_link_attachment.network != null
    error_message = "network is required when Private Link Attachment is enabled"
  }

  validation {
    condition     = !var.private_link_attachment.enabled || var.private_link_attachment.subnetwork != null
    error_message = "subnetwork is required when Private Link Attachment is enabled"
  }
}

# =============================================================================
# Bastion Host Variables
# =============================================================================

variable "bastion_host" {
  type = object({
    enabled       = bool
    machine_type  = optional(string, "e2-micro")
    zone          = optional(string)
    allowed_cidrs = optional(list(string), ["0.0.0.0/0"])
  })
  description = <<-EOT
    Bastion host configuration for SSH tunneling to private Confluent clusters.
    Creates a GCP VM that can be used as an SSH jump host for port forwarding.
    Simpler alternative to VPN for accessing private endpoints.

    - enabled: Whether to create the bastion host
    - machine_type: GCP machine type for the VM (default: e2-micro)
    - zone: GCP zone for the VM (defaults to region-b)
    - allowed_cidrs: Source CIDRs allowed to SSH to the bastion (default: ["0.0.0.0/0"])
  EOT
  default = {
    enabled = false
  }
}

# =============================================================================
# Cluster Link Variables
# =============================================================================

variable "cluster_link" {
  type = object({
    enabled                   = bool
    link_name                 = optional(string)
    source_cluster_id         = optional(string)
    source_bootstrap_endpoint = optional(string)
    source_api_key            = optional(string)
    source_api_secret         = optional(string)
    mirror_topics             = optional(list(string), [])
    local_rest_endpoint_port  = optional(number)
    config                    = optional(map(string), {})
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
    - config: Map of cluster link configuration options (e.g., {"acl.sync.enable" = "true"})
      See: https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html
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
