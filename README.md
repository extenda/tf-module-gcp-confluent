# tf-module-gcp-confluent

## Description

This provider creates Confluentcloud Kafka cluster, and stores API Key and Secret in GCP Project Secret manager.

## Requirements

| Name | Version |
|------|---------|
| confluentcloud | 0.0.5 |

## Providers

| Name | Version |
|------|---------|
| confluentcloud | 0.0.5 |
| google-beta | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| availability | Availability: LOW(single-zone) or HIGH(multi-zone) | `string` | `"LOW"` | no |
| confluent\_password | Confluentcloud password or GCP secretname to extract password if var.confluent\_project\_gcp\_secret provided | `string` | `"confluent-password"` | no |
| confluent\_project\_gcp\_secret | GCP project ID having secret for confluentcloud credentials | `string` | `"tf-admin-90301274"` | no |
| confluent\_username | Confluentcloud username or GCP secretname to extract username if var.confluent\_project\_gcp\_secret provided | `string` | `"confluent-username"` | no |
| deployment\_sku | Deployment parameter sku | `string` | `"BASIC"` | no |
| environment | Environment ID to create cluster in | `string` | n/a | yes |
| name | The name of the cluster | `string` | n/a | yes |
| network\_egress | Network egress limit (MBps) | `number` | `0` | no |
| network\_ingress | Network ingress limit (MBps) | `number` | `0` | no |
| project\_id | Project ID to add Kafka secrets | `string` | `""` | no |
| region | Region to create cluster in | `string` | `"europe-west1"` | no |
| storage | Cluster storage limit (GB) | `number` | `0` | no |

## Outputs

| Name | Description |
|------|-------------|
| kafka\_url | URL of the kafka cluster |
| key | API Key for the Kafka cluster |
| secret | API Secret for the Kafka cluster |
