terraform {
  required_providers {
    confluentcloud = {
      source  = "Mongey/confluentcloud"
      version = "0.0.6"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}
