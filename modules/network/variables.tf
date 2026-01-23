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

variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "project_id" {
  description = "GCP project for resources"
  type        = string
}

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
