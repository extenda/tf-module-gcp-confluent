variable confluent_auth_project {
  description = "GCP project ID having secret for confluentcloud credentials"
  type        = string
  default     = "tf-admin-90301274"
}

variable confluent_secrets {
  description = "List of secrets to extract from Secret Manager for Auth"
  type        = list(string)
  default     = ["tf-confluent-api-key", "tf-confluent-api-secret"]
}

variable environment {
  description = "Environment ID to create cluster in"
  type        = string
}

variable name {
  description = "The name of the cluster"
  type        = string
}

variable region {
  description = "Region to create cluster in"
  type        = string
  default     = "europe-west1"
}

variable availability {
  description = "The availability zone configuration of the Kafka cluster. Accepted values are: SINGLE_ZONE and MULTI_ZONE"
  type        = string
  default     = "SINGLE_ZONE"
}

variable project_env {
  type        = string
  description = "Staging or prod environment"
}

variable project_id {
  description = "Project ID to add Kafka secrets"
  type        = string
}

variable schema_registry_region {
  description = "Region for schema registry"
  type        = string
  default     = "sgreg-5" #europe-west3
}

variable package {
  type        = string
  default     = "ESSENTIALS"
  description = "The type of the billing package. Accepted values are: ESSENTIALS and ADVANCED"
}

variable terraform_runner_user_id {
  type        = string
  default     = "u-4vy3kp"
  description = "ID of a user account to use for API keys creation"
}
