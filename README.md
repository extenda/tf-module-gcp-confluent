# tf-module-gcp-confluent

## Description

This provider creates Confluentcloud Kafka cluster, and stores API Key and Secret in GCP Project Secret manager.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.4.6 |
| confluent | 1.43.0 |
| google | ~> 4.62.0 |

## Providers

| Name | Version |
|------|---------|
| confluent | 1.43.0 |
| google | ~> 4.62.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| availability | The availability zone configuration of the Kafka cluster. Accepted values are: SINGLE\_ZONE and MULTI\_ZONE | `string` | `"SINGLE_ZONE"` | no |
| confluent\_auth\_project | GCP project ID having secret for confluentcloud credentials | `string` | `"tf-admin-90301274"` | no |
| confluent\_secrets | List of secrets to extract from Secret Manager for Auth | `list(string)` | <pre>[<br>  "tf-confluent-api-key",<br>  "tf-confluent-api-secret"<br>]</pre> | no |
| environment | Environment ID to create cluster in | `string` | n/a | yes |
| name | The name of the cluster | `string` | n/a | yes |
| package | The type of the billing package. Accepted values are: ESSENTIALS and ADVANCED | `string` | `"ESSENTIALS"` | no |
| project\_env | Staging or prod environment | `string` | n/a | yes |
| project\_id | Project ID to add Kafka secrets | `string` | n/a | yes |
| region | Region to create cluster in | `string` | `"europe-west1"` | no |
| schema\_registry\_region | Region for schema registry | `string` | `"sgreg-5"` | no |
| terraform\_runner\_user\_id | ID of a user account to use for API keys creation | `string` | `"u-4vy3kp"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_id | ID of created kafka cluster |
| environment\_id | ID of created confluent environment |
| kafka\_cluster\_api\_key | API Key/Secret for the Kafka cluster |
| kafka\_cluster\_url | URL of the kafka cluster |
