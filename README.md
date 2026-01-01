# tf-module-gcp-confluent

## Description

This module creates a Confluent Cloud Kafka cluster on GCP and stores API Keys and Secrets in GCP Secret Manager.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.7 |
| confluent | 2.57.0 |
| google | ~> 4.62.0 |

## Providers

| Name | Version |
|------|---------|
| confluent | 2.57.0 |
| google | ~> 4.62.0 |

## Upgrade from v1.x

This module uses Confluent provider v2.x which has breaking changes:

- **Schema Registry**: Now auto-provisioned with environments. The `schema_registry_region` and `package` variables have been removed.
- **Cluster Type**: Use the new `cluster_type` variable instead of `project_env`. The `project_env` variable is deprecated but still supported for backwards compatibility.
- **Terraform Version**: Requires Terraform >= 1.5.7

### Migration Steps

1. Update your Terraform version to >= 1.5.7
2. Remove `schema_registry_region` and `package` from your module calls
3. (Recommended) Replace `project_env` with `cluster_type`:
   - `project_env = "staging"` → `cluster_type = "basic"`
   - `project_env = "prod"` → `cluster_type = "standard"`
4. Run `terraform state rm` for the Schema Registry cluster resource before applying (it's now a data source)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| availability | The availability zone configuration of the Kafka cluster. Accepted values are: SINGLE\_ZONE and MULTI\_ZONE | `string` | `"SINGLE_ZONE"` | no |
| cluster\_type | The type of Kafka cluster. Accepted values are: basic, standard, enterprise | `string` | `null` | no |
| confluent\_auth\_project | GCP project ID having secret for confluentcloud credentials | `string` | `"tf-admin-90301274"` | no |
| confluent\_secrets | List of secrets to extract from Secret Manager for Auth | `list(string)` | <pre>[<br>  "tf-confluent-api-key",<br>  "tf-confluent-api-secret"<br>]</pre> | no |
| environment | Environment display name to create | `string` | n/a | yes |
| name | The name of the cluster | `string` | n/a | yes |
| project\_env | Staging or prod environment (deprecated: use cluster\_type instead) | `string` | `null` | no |
| project\_id | Project ID to add Kafka secrets | `string` | n/a | yes |
| region | Region to create cluster in | `string` | `"europe-west1"` | no |
| terraform\_runner\_user\_id | ID of a user account to use for API keys creation | `string` | `"u-4vy3kp"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_id | ID of created kafka cluster |
| environment\_id | ID of created confluent environment |
| kafka\_cluster\_api\_key | API Key/Secret for the Kafka cluster |
| kafka\_cluster\_url | URL of the kafka cluster |
