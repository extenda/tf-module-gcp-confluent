# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform module that provisions Confluent Cloud Kafka infrastructure on GCP. It creates:
- Confluent environment and Kafka cluster (basic, standard, or enterprise)
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

**Cluster type logic**: `cluster_type` variable controls cluster tier - "basic", "standard", or "enterprise". For backwards compatibility, `project_env` is still supported ("staging" → basic, "prod" → standard).

**Lifecycle protection**: Both `confluent_environment` and `confluent_kafka_cluster` have `prevent_destroy = true`.

## Required Variables

- `environment` - Confluent environment display name
- `name` - Kafka cluster name
- `cluster_type` - One of: "basic", "standard", "enterprise" (or use deprecated `project_env`)
- `project_id` - GCP project where Kafka secrets will be stored

## Provider Versions

- Terraform >= 1.5.7
- Confluent provider: 2.57.0
- Google provider: ~> 4.62.0
