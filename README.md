<!-- Update this title with a descriptive name. Use sentence case. -->
# IBM Cloud OpenShift Terraform Enterprise modules

[![Implemented](https://img.shields.io/badge/Status-Implemented%20(No%20quality%20checks)-yellowgreen)](https://terraform-ibm-modules.github.io/documentation/#/badge-status)
[![latest release](https://img.shields.io/github/v/release/terraform-ibm-modules/terraform-ibm-terraform-enterprise?logo=GitHub&sort=semver)](https://github.com/terraform-ibm-modules/terraform-ibm-terraform-enterprise/releases/latest)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com/)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-623CE4?logo=terraform)](https://registry.terraform.io/modules/terraform-ibm-modules/terraform-enterprise/ibm/latest)

## Overview

This module deploys Terraform Enterprise on IBM Cloud, provisioning all required supporting infrastructure — VPC, Red Hat OpenShift cluster, Cloud Object Storage, IBM Cloud Databases for PostgreSQL and Redis — and installs Terraform Enterprise via its official Helm chart.

> **Status:** This module does not yet implement all production-ready requirements such as network isolation, security hardening, and compliance controls. The module interfaces and behaviours may change as these capabilities are added. Early adopters are encouraged to try it and provide feedback.

This module automates the setup of namespaces, secrets, Helm releases, OpenShift routes, and supporting resources required for a Terraform Enterprise installation.

### Terraform Enterprise Secondary hostname

This module supports configuring the Terraform Enterprise instance with a [secondary hostname](https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration#tfe_hostname_secondary) by:
- integrating it with an existing IBM Cloud Internet Services instance providing an already configured domain (i.e. `example.com`) for the DNS support
- providing the host to add to the existing domain DNS configuration (i.e. `tfe-host`) and to configure the route for the final secondary Fully Qualified Domain Name (FQDN) on the OCP cluster (i.e. `tfe-host.example.com`)
- integrating it with an existing secret on IBM Secrets Manager instance to pull the TLS certificate to configure for the OpenShift route that serves the secondary FQDN.

## Required access policies

You need the following permissions to run this module:

- IBM Cloud Resource Group: `Viewer` access on the resource group
- IBM Cloud OpenShift: `Editor` or `Administrator` access to the cluster
- IBM Cloud Object Storage: `Manager` or `Writer` access for the S3 bucket
- IBM Cloud Databases for PostgreSQL/Redis: `Manager` or equivalent access
- IBM Cloud Secrets Manager: `Writer` access if the generated secrets are to be stored in Secrets Manager
- IBM Cloud Secrets Manager: `SecretsReader` access if the Terraform Enterprise license key is in Secrets Manager
- Ability to create and manage Kubernetes resources in the target OpenShift namespace

## Contributing

You can report issues and request features for this module in GitHub issues in the module repo. See [Report an issue or request a feature](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md).

To set up your local development environment, see [Local development setup](https://terraform-ibm-modules.github.io/documentation/#/local-dev-setup) in the project documentation.

## Helm Chart Configuration

This module deploys Terraform Enterprise using the official HashiCorp Helm chart from a remote repository. You must specify:

- **`tfe_helm_chart_version`** (required): The specific version of the Helm chart to deploy (e.g., `"1.6.3"`)
- **`tfe_helm_repository`** (optional): The Helm repository URL (defaults to `"https://helm.releases.hashicorp.com"`)

### Example Configuration

```hcl
module "terraform_enterprise" {
  source = "terraform-ibm-modules/terraform-enterprise/ibm"

  tfe_helm_chart_version = "1.6.3"
  tfe_helm_repository    = "https://helm.releases.hashicorp.com"  # Optional, this is the default
  tfe_image_tag          = "v202506-1"

  # ... other required variables
}
```

**Important:** Ensure the Helm chart version is compatible with your image tag (`tfe_image_tag`). Refer to the [HashiCorp Terraform Enterprise documentation](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/kubernetes/install) for compatibility information.

## Deployed resource naming

All resources created by this module are named using the `prefix` variable. Setting `prefix = "prod"` produces names such as:

| Resource | Name |
|---|---|
| VPC | `prod-vpc` |
| OpenShift cluster | `prod-cluster` |
| Key Protect instance | `prod-kms` |
| Cloud Object Storage instance | `prod-cos` |
| COS bucket | `prod-cos-bucket-<suffix>` |
| PostgreSQL instance | `prod-data-store` |
| Redis instance | `prod-redis` |
| Secrets Manager secret group | `prod-secrets-group` |

Set `prefix = null` or `prefix = ""` to skip prefixing entirely and use the names as-is.

## Upgrade guide

To upgrade Terraform Enterprise to a new version:

1. Check the [Terraform Enterprise release notes](https://developer.hashicorp.com/terraform/enterprise/releases) and the [Helm chart changelog](https://github.com/hashicorp/terraform-enterprise-helm/blob/main/CHANGELOG.md) for the target version.
2. Update `tfe_image_tag` to the new image version (e.g. `"2.0.5"`).
3. Update `tfe_helm_chart_version` to the corresponding Helm chart version (e.g. `"2.0.5"`).
4. Run `terraform plan` and review the diff — expect a Helm release update only.
5. Run `terraform apply`. The Helm chart performs a rolling update; existing runs continue until pods are replaced.

> **Important:** Never skip major versions. Follow HashiCorp's [upgrade path guidance](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/kubernetes/upgrade).

## Backup strategy

Terraform Enterprise state and data is stored across three IBM Cloud managed services:

| Service | What it holds | IBM backup policy |
|---|---|---|
| **IBM Cloud Databases for PostgreSQL** | Runs, workspaces, organisations, variables | Automatic daily backups retained for 30 days |
| **Cloud Object Storage** | Terraform state files and artefacts | Versioning available; configure retention policies via `cos_retention_*` variables |
| **IBM Cloud Databases for Redis** | Session data and transient queue data | Automatic daily backups retained for 30 days |

For disaster recovery, restore PostgreSQL first, then COS, then restart Terraform Enterprise pods. Refer to the [IBM Cloud Databases restore documentation](https://cloud.ibm.com/docs/databases-for-postgresql?topic=databases-for-postgresql-dashboard-backups) for step-by-step instructions.

## Notes

The module integrates with IBM Cloud Secret Manager service. This integration takes two forms. If an optional IBM Cloud Secrets Manager instance CRN and secret group ID are provided, then the Redis admin user password and Terraform Enterprise admin token will be stored in Secrets Manager and the new secret CRNs will be returned instead of the secret values. If an optional Terraform Enterprise license secret CRN is provided, then the license will be retrieved from Secrets Manager, avoiding the need to pass the license key as a string.

## Known issues

Tear down will fail at the Postgresql instance when delete protection is enabled. Set the delete protection flag to false and run `terraform apply --target 'module.<top level module name>.module.icd_postgres.ibm_database.postgresql_db'` before running the destroy to complete the tear down.
