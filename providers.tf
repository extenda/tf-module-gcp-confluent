terraform {
  required_providers {
    confluentcloud = {
      source  = "Mongey/confluentcloud"
      version = "0.0.15"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}
