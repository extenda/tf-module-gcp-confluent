# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform module that provisions Confluent Cloud Kafka infrastructure on GCP. It creates:
- Confluent environment and Kafka cluster (basic, standard, enterprise, or dedicated)
- Optional Private Service Connect network for dedicated clusters
- API keys for both Kafka and Schema Registry
- GCP Secret Manager secrets containing connection credentials

Schema Registry is auto-provisioned with environments in Confluent provider v2.x and accessed via data source.

## Commands

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## Architecture

The module uses a two-provider setup:
- **Google provider**: Reads Confluent credentials from GCP Secret Manager, stores generated Kafka secrets
- **Confluent provider**: Creates Kafka infrastructure (authenticated via secrets from GCP)

**Credential flow**: GCP Secret Manager (source) → Confluent provider auth → Create resources → Store new secrets back to GCP Secret Manager (target project)

**Cluster type logic**: `cluster_type` variable (required) controls cluster tier - "basic", "standard", "enterprise", or "dedicated". Dedicated clusters require `dedicated_cku` configuration.

## Private Networking Options

This module supports two private networking approaches:

### Private Service Connect (for Dedicated clusters)
Variable: `private_service_connect`

When `private_service_connect.enabled = true`:
- Creates `confluent_network` with PRIVATELINK connection type
- Creates `confluent_private_link_access` for GCP project authorization
- Only supported with dedicated clusters
- Automatically sets availability to MULTI_ZONE
- User must create their own GCP PSC endpoints using the output `service_attachments`

### Private Link Attachment (for Enterprise/serverless clusters)
Variable: `private_link_attachment`

When `private_link_attachment.enabled = true`:
- Creates `confluent_private_link_attachment` (PLATT reservation in Confluent Cloud)
- Creates full GCP-side infrastructure automatically:
  - `google_compute_address` - Static internal IP
  - `google_compute_forwarding_rule` - PSC endpoint
  - `google_dns_managed_zone` - Private DNS zone (`<region>.gcp.private.confluent.cloud`)
  - `google_dns_record_set` - Wildcard A record
- Creates `confluent_private_link_attachment_connection` to register endpoint with Confluent

**Note:** These options are mutually exclusive.

**Lifecycle protection**: `confluent_environment`, `confluent_kafka_cluster`, `confluent_network`, and `confluent_private_link_attachment` have `prevent_destroy = true`.

## Cluster Link (Data Replication)

Variable: `cluster_link`

When `cluster_link.enabled = true`:
- Creates a destination-initiated `confluent_cluster_link` to replicate data from an existing source cluster
- The created cluster acts as the **destination** (receives data from source)
- Supports optional mirror topic creation via `mirror_topics` list

**Configuration:**
```hcl
cluster_link = {
  enabled                   = true
  link_name                 = "my-cluster-link"           # Optional, defaults to "<cluster_name>-link"
  source_cluster_id         = "lkc-abc123"                # Required: source cluster ID
  source_bootstrap_endpoint = "pkc-xxxxx.region.gcp.confluent.cloud:9092"  # Required
  source_api_key            = "XXXXXXXXXX"                # Required: API key for source cluster
  source_api_secret         = "XXXXXXXXXX"                # Required: API secret for source cluster
  mirror_topics             = ["topic1", "topic2"]        # Optional: topics to mirror
}
```

**Network considerations:**
- Destination-initiated links work well when the destination has private networking (PLATT) and source is public
- The destination cluster initiates outbound connections to the source's public endpoint

## Required Variables

- `environment` - Confluent environment display name
- `name` - Kafka cluster name
- `cluster_type` - One of: "basic", "standard", "enterprise", "dedicated"
- `project_id` - GCP project where Kafka secrets will be stored

## Provider Versions

- Terraform >= 1.5.7
- Confluent provider: 2.57.0
- Google provider: ~> 4.62.0
