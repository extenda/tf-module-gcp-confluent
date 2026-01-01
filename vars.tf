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

variable "environment" {
  description = "Environment ID to create cluster in"
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

variable "project_id" {
  description = "Project ID to add Kafka secrets"
  type        = string
}

variable "terraform_runner_user_id" {
  type        = string
  default     = "u-4vy3kp"
  description = "ID of a user account to use for API keys creation"
}
