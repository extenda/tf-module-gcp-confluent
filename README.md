# tf-module-gcp-confluent

## Description

This provider creates Confluentcloud Kafka cluster, and stores API Key and Secret in GCP Project Secret manager.

## Requirements

| Name | Version |
|------|---------|
| confluentcloud | 0.0.5 |

As released version doesn't support `confluentcloud_schema_registry` resource yet, own binaries was compiled from commit `6e2cbc35fa0143d3f4466135ec06de95ce99e180` and placed to storage bucket.
Provider binaries are available by:

https://storage.googleapis.com/tf-registry-extenda/terraform-provider-confluentcloud_0.0.5a-6e2cbc3_linux_amd64.zip

https://storage.googleapis.com/tf-registry-extenda/terraform-provider-confluentcloud_0.0.5a-6e2cbc3_darwin_amd64.zip

https://storage.googleapis.com/tf-registry-extenda/terraform-provider-confluentcloud_0.0.5a-6e2cbc3_windows_amd64.zip


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
| network\_egress | Network egress limit (MBps) | `number` | `100` | no |
| network\_ingress | Network ingress limit (MBps) | `number` | `100` | no |
| project\_id | Project ID to add Kafka secrets | `string` | `""` | no |
| region | Region to create cluster in | `string` | `"europe-west1"` | no |
| schema\_registry\_region | Region for schema registry | `string` | `"EU"` | no |
| service\_accounts | List of service accounts to create | `list(string)` | `[]` | no |
| storage | Cluster storage limit (GB) | `number` | `5000` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_id | ID of created kafka cluster |
| environment\_id | ID of created confluent environment |
| api\_key | API Key/Secret for the Kafka cluster |
| kafka\_url | URL of the kafka cluster |
| service\_account\_api\_keys | Map of API Keys/Secrets for the service accounts |
| service\_account\_ids | Map of service account IDs |
