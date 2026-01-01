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
- **Cluster Type**: The `project_env` variable has been removed. Use `cluster_type` instead.
- **Terraform Version**: Requires Terraform >= 1.5.7

### Migration Steps

1. Update your Terraform version to >= 1.5.7
2. Remove `schema_registry_region` and `package` from your module calls
3. Replace `project_env` with `cluster_type`:
   - `project_env = "staging"` → `cluster_type = "basic"`
   - `project_env = "prod"` → `cluster_type = "standard"`
4. Run `terraform state rm` for the Schema Registry cluster resource before applying (it's now a data source)

## Private Service Connect

This module supports Private Service Connect for dedicated clusters. When enabled, traffic between your GCP applications and Confluent Cloud does not traverse the public internet.

### Usage

```hcl
module "confluent" {
  source = "github.com/extenda/tf-module-gcp-confluent"

  environment  = "production"
  name         = "my-kafka-cluster"
  cluster_type = "dedicated"
  project_id   = "my-gcp-project"

  private_service_connect = {
    enabled        = true
    gcp_project_id = "my-gcp-project"  # GCP project that will connect via PSC
  }
}
```

### Creating GCP Private Service Connect Endpoints

After applying the module, use the `private_service_connect` output to create GCP endpoints:

```hcl
# The module outputs service attachments per zone
# Example: module.confluent.private_service_connect.service_attachments
# {
#   "europe-west1-a" = "projects/.../serviceAttachments/..."
#   "europe-west1-b" = "projects/.../serviceAttachments/..."
#   "europe-west1-c" = "projects/.../serviceAttachments/..."
# }
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| availability | The availability zone configuration of the Kafka cluster. Accepted values are: SINGLE\_ZONE and MULTI\_ZONE | `string` | `"SINGLE_ZONE"` | no |
| cluster\_type | The type of Kafka cluster. Accepted values are: basic, standard, enterprise, dedicated | `string` | n/a | yes |
| confluent\_auth\_project | GCP project ID having secret for confluentcloud credentials | `string` | `"tf-admin-90301274"` | no |
| confluent\_secrets | List of secrets to extract from Secret Manager for Auth | `list(string)` | <pre>[<br>  "tf-confluent-api-key",<br>  "tf-confluent-api-secret"<br>]</pre> | no |
| dedicated\_cku | Number of CKUs for dedicated cluster. Required when cluster\_type is 'dedicated'. Minimum 2 for MULTI\_ZONE. | `number` | `2` | no |
| environment | Environment display name to create | `string` | n/a | yes |
| name | The name of the cluster | `string` | n/a | yes |
| private\_service\_connect | Private Service Connect configuration. Only supported with dedicated cluster type. | `object` | `{ enabled = false }` | no |
| project\_id | Project ID to add Kafka secrets | `string` | n/a | yes |
| region | Region to create cluster in | `string` | `"europe-west1"` | no |
| terraform\_runner\_user\_id | ID of a user account to use for API keys creation | `string` | `"u-4vy3kp"` | no |

### private\_service\_connect Object

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| enabled | Enable Private Service Connect | `bool` | yes |
| gcp\_project\_id | GCP project ID that will connect via Private Service Connect | `string` | yes (when enabled) |
| network\_name | Custom name for the Confluent network | `string` | no |
| zones | List of GCP zones (defaults to region-a, region-b, region-c) | `list(string)` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_id | ID of created kafka cluster |
| environment\_id | ID of created confluent environment |
| kafka\_cluster\_api\_key | API Key/Secret for the Kafka cluster |
| kafka\_cluster\_url | URL of the kafka cluster |
| private\_service\_connect | Private Service Connect configuration including service attachments for creating GCP endpoints |
