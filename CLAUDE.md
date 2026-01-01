# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform module that provisions Confluent Cloud Kafka infrastructure on GCP. It creates:
- Confluent environment and Kafka cluster
- Schema Registry cluster
- API keys for both Kafka and Schema Registry
- GCP Secret Manager secrets containing connection credentials

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

**Cluster tier logic**: `project_env` variable controls cluster type - "staging" creates Basic tier, "prod" creates Standard tier (see dynamic blocks in `main.tf`).

**Lifecycle protection**: Both `confluent_environment` and `confluent_kafka_cluster` have `prevent_destroy = true`.

## Required Variables

- `environment` - Confluent environment display name
- `name` - Kafka cluster name
- `project_env` - Must be "staging" or "prod" (determines cluster tier)
- `project_id` - GCP project where Kafka secrets will be stored

## Provider Versions

- Terraform >= 1.4.6
- Confluent provider: 1.43.0
- Google provider: ~> 4.62.0
