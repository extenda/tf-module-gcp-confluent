terraform {
  required_version = ">= 1.5.7"
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.57.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.62.0"
    }
  }
}
