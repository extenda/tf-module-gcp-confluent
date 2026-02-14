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

variable "enterprise_max_ecku" {
  type        = number
  description = "Maximum number of Elastic CKUs (eCKUs) for enterprise cluster auto-scaling. Minimum 2 for MULTI_ZONE."
  default     = null
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
