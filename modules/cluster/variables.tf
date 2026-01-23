variable "environment_id" {
  description = "ID of the Confluent environment (from network module)"
  type        = string
}

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

variable "network_id" {
  description = "Confluent network ID for Private Service Connect (from network module, null if not using PSC)"
  type        = string
  default     = null
}

variable "use_private_service_connect" {
  description = "Whether Private Service Connect is enabled (forces MULTI_ZONE availability)"
  type        = bool
  default     = false
}

variable "schema_registry" {
  description = "Schema Registry credentials from network module (for storing in GCP secrets)"
  type = object({
    api_key       = string
    api_secret    = string
    rest_endpoint = string
  })
  default   = null
  sensitive = true
}

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

# Variables for SSH tunnel instructions (from network module)
variable "bastion_enabled" {
  description = "Whether bastion host is enabled (from network module)"
  type        = bool
  default     = false
}

variable "bastion_instance_name" {
  description = "Bastion instance name (from network module)"
  type        = string
  default     = null
}

variable "bastion_zone" {
  description = "Bastion zone (from network module)"
  type        = string
  default     = null
}

variable "platt_enabled" {
  description = "Whether Private Link Attachment is enabled (from network module)"
  type        = bool
  default     = false
}

variable "platt_endpoint_ip" {
  description = "Private Link Attachment endpoint IP (from network module)"
  type        = string
  default     = null
}

variable "platt_gcp_project" {
  description = "GCP project for Private Link Attachment resources (from network module)"
  type        = string
  default     = null
}

variable "platt_dns_domain" {
  description = "DNS domain for Private Link Attachment (from network module)"
  type        = string
  default     = null
}
