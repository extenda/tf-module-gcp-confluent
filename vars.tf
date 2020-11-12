variable confluent_project_gcp_secret {
  description = "GCP project ID having secret for confluentcloud credentials"
  type        = string
  default     = "tf-admin-90301274"
}

variable confluent_username {
  description = "Confluentcloud username or GCP secretname to extract username if var.confluent_project_gcp_secret provided"
  type        = string
  default     = "confluent-username"
}

variable confluent_password {
  description = "Confluentcloud password or GCP secretname to extract password if var.confluent_project_gcp_secret provided"
  type        = string
  default     = "confluent-password"
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
  description = "Availability: LOW(single-zone) or HIGH(multi-zone)"
  type        = string
  default     = "LOW"
}

variable storage {
  description = "Cluster storage limit (GB)"
  type        = number
  default     = 5000
}

variable network_ingress {
  description = "Network ingress limit (MBps)"
  type        = number
  default     = 100
}

variable network_egress {
  description = "Network egress limit (MBps)"
  type        = number
  default     = 100
}

variable deployment_sku {
  description = "Deployment parameter sku"
  type        = string
  default     = "BASIC"
}


variable project_id {
  description = "Project ID to add Kafka secrets"
  type        = string
  default     = ""
}

variable schema_registry_region {
  description = "Region for schema registry"
  type        = string
  default     = "EU"
}

variable service_accounts {
  description = "List of service accounts to create"
  type = list(string)
  default = []
}