terraform {
  required_version = ">= 1.4.6"
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.57.0"
    }
  }
}
