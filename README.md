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

## Secret Naming

GCP Secret Manager secrets include the cluster type in their names to avoid collisions when multiple clusters exist in the same project. Secret names follow this pattern:

```
kafka_cluster_api_key_<cluster_type>
kafka_cluster_api_secret_<cluster_type>
kafka_cluster_bootstrap_server_<cluster_type>
kafka_schema_registry_key_<cluster_type>
kafka_schema_registry_secret_<cluster_type>
kafka_schema_registry_url_<cluster_type>
spring_cloud_stream_kafka_binder_brokers_<cluster_type>
spring_kafka_properties_sasl_jaas_config_<cluster_type>
spring_kafka_properties_schema_registry_basic_auth_user_info_<cluster_type>
```

For example, a `standard` cluster creates `kafka_cluster_api_key_standard`, while an `enterprise` cluster creates `kafka_cluster_api_key_enterprise`.

**Breaking Change**: If upgrading from a version without cluster type suffixes, you'll need to either:
1. Migrate your applications to use the new secret names, or
2. Run `terraform state rm` for the old secrets and let Terraform create the new ones

## Environment Configuration

By default, the module creates a new Confluent environment. You can also use an existing environment by setting `create_environment = false` and providing the `environment_id`.

### Create New Environment (default)

```hcl
module "confluent" {
  source = "github.com/extenda/tf-module-gcp-confluent"

  environment  = "my-new-environment"
  name         = "my-kafka-cluster"
  cluster_type = "enterprise"
  project_id   = "my-gcp-project"
}
```

### Use Existing Environment

```hcl
module "confluent" {
  source = "github.com/extenda/tf-module-gcp-confluent"

  create_environment = false
  environment_id     = "env-abc123"
  environment        = "unused"  # Required but ignored when using existing environment
  name               = "my-kafka-cluster"
  cluster_type       = "enterprise"
  project_id         = "my-gcp-project"
}
```

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

## Private Link Attachment (PLATT)

This module supports Private Link Attachment for Enterprise and serverless clusters. Unlike Private Service Connect (which requires dedicated clusters and manual GCP endpoint creation), PLATT automatically creates all necessary GCP-side infrastructure including the Private Service Connect endpoint and private DNS configuration.

**Note:** Private Service Connect and Private Link Attachment are mutually exclusive.

### Usage

```hcl
module "confluent" {
  source = "github.com/extenda/tf-module-gcp-confluent"

  environment  = "production"
  name         = "my-kafka-cluster"
  cluster_type = "enterprise"
  project_id   = "my-gcp-project"

  private_link_attachment = {
    enabled    = true
    network    = "projects/my-gcp-project/global/networks/my-vpc"
    subnetwork = "projects/my-gcp-project/regions/europe-west1/subnetworks/my-subnet"
  }
}
```

### What Gets Created

When enabled, the module creates:

1. **Confluent Private Link Attachment** - Reserves a PLATT endpoint in Confluent Cloud
2. **GCP Static IP** - Internal IP address for the PSC endpoint
3. **GCP Forwarding Rule** - The Private Service Connect endpoint
4. **Private DNS Zone** - Zone for `<region>.gcp.private.confluent.cloud`
5. **DNS Wildcard Record** - Routes all Confluent traffic to the PSC endpoint
6. **PLATT Connection** - Registers the GCP endpoint with Confluent

After applying, your applications in the specified VPC can connect to Kafka using the private endpoint automatically via DNS resolution.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| availability | The availability zone configuration of the Kafka cluster. Accepted values are: SINGLE\_ZONE and MULTI\_ZONE | `string` | `"SINGLE_ZONE"` | no |
| cluster\_type | The type of Kafka cluster. Accepted values are: basic, standard, enterprise, dedicated | `string` | n/a | yes |
| confluent\_auth\_project | GCP project ID having secret for confluentcloud credentials | `string` | `"tf-admin-90301274"` | no |
| confluent\_secrets | List of secrets to extract from Secret Manager for Auth | `list(string)` | <pre>[<br>  "tf-confluent-api-key",<br>  "tf-confluent-api-secret"<br>]</pre> | no |
| create\_environment | Whether to create a new Confluent environment. Set to false to use an existing environment. | `bool` | `true` | no |
| dedicated\_cku | Number of CKUs for dedicated cluster. Required when cluster\_type is 'dedicated'. Minimum 2 for MULTI\_ZONE. | `number` | `2` | no |
| environment | Confluent environment display name (used when creating a new environment) | `string` | n/a | yes |
| environment\_id | ID of an existing Confluent environment. Required when create\_environment is false. | `string` | `null` | no |
| name | The name of the cluster | `string` | n/a | yes |
| private\_link\_attachment | Private Link Attachment (PLATT) configuration. For Enterprise/serverless clusters. | `object` | `{ enabled = false }` | no |
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

### private\_link\_attachment Object

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| enabled | Enable Private Link Attachment | `bool` | yes |
| network | Full self-link of the GCP VPC network | `string` | yes (when enabled) |
| subnetwork | Full self-link of the GCP subnetwork | `string` | yes (when enabled) |
| name | Custom name for the PLATT resources | `string` | no |
| gcp\_project | GCP project for the PSC endpoint (defaults to project\_id) | `string` | no |
| ip\_address | Specific internal IP to use for the endpoint | `string` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_id | ID of created kafka cluster |
| environment\_id | ID of the Confluent environment (created or existing) |
| kafka\_cluster\_api\_key | API Key/Secret for the Kafka cluster |
| kafka\_cluster\_url | URL of the kafka cluster |
| private\_link\_attachment | Private Link Attachment (PLATT) configuration including endpoint details and DNS zone |
| private\_service\_connect | Private Service Connect configuration including service attachments for creating GCP endpoints |
