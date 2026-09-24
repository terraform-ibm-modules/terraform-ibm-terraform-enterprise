########################################################################################################################
# Input Variables
########################################################################################################################

variable "region" {
  type        = string
  description = "Region where resources are created"
}

variable "resource_group_id" {
  type        = string
  description = "The ID of the resource group to use for the creation of the Terraform Enterprise instance and the related resources."
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "Optional list of access tags to be added to created resources"
  default     = []
}

##############################################################################
# Terraform Enterprise
##############################################################################

variable "tfe_license" {
  type        = string
  description = "The license key for Terraform Enterprise"
  default     = null
  sensitive   = true
}

variable "tfe_encryption_password" {
  type        = string
  description = "The encryption password used by Terraform Enterprise to protect sensitive data at rest. Must be kept secret and consistent across upgrades — changing this value requires a migration procedure."
  sensitive   = true
}

variable "tfe_license_secret_crn" {
  type        = string
  description = "The CRN of the Secrets Manager secret containing the license key for Terraform Enterprise"
  default     = null

  validation {
    condition     = !(var.tfe_license == null && var.tfe_license_secret_crn == null)
    error_message = "Exactly one of `tfe_license_secret_crn` or `tfe_license` must be set"
  }

  validation {
    condition     = !(var.tfe_license != null && var.tfe_license_secret_crn != null)
    error_message = "Only one of `tfe_license_secret_crn` or `tfe_license` must be set"
  }

  validation {
    condition = anytrue([
      var.tfe_license_secret_crn == null,
      can(regex("^crn:v\\d:(.*:){2}secrets-manager:(.*:)([aos]\\/[\\w_\\-]+):[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}:secret:[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", var.tfe_license_secret_crn))
    ])
    error_message = "The value provided for 'tfe_license_secret_crn' is not valid."
  }
}

variable "admin_username" {
  type        = string
  description = "The user name of the Terraform Enterprise admin user"
}

variable "admin_email" {
  type        = string
  description = "The email address of the Terraform Enterprise admin user"
}

variable "admin_password" {
  type        = string
  description = "The password for the Terraform Enterprise admin user"
  sensitive   = true
}

# renovate: datasource=github-releases depName=hashicorp/terraform-enterprise
variable "tfe_image_tag" {
  type        = string
  description = "The version tag of the Terraform Enterprise image to use. Check on https://developer.hashicorp.com/terraform/enterprise/releases for available versions."
  default     = "2.0.5"
}

variable "tfe_image_repository" {
  type        = string
  description = "The container image registry to pull the Terraform Enterprise image from. Defaults to HashiCorp's official registry ('images.releases.hashicorp.com/hashicorp/terraform-enterprise'). For IBM Passport Advantage customers, set to 'cp.icr.io/cp/hashicorp/terraform-enterprise'."
  default     = "images.releases.hashicorp.com/hashicorp/terraform-enterprise"
  nullable    = false
}

variable "tfe_image_pull_secret_username" {
  type        = string
  description = "The username used to authenticate with the image registry for the pull secret. For HashiCorp's official registry this is always 'terraform'. For IBM Cloud Container Registry (cp.icr.io) set this to 'iamapikey' and set the image pull password to your IBM Cloud API key."
  default     = "terraform"
  nullable    = false
}

# renovate: datasource=helm depName=terraform-enterprise registryUrl=https://helm.releases.hashicorp.com
variable "tfe_helm_chart_version" {
  type        = string
  description = "The version of the Terraform Enterprise Helm chart to use. Default to 2.0.5 . Check on https://github.com/hashicorp/terraform-enterprise-helm/blob/main/CHANGELOG.md for available versions."
  default     = "2.0.5"
}

variable "tfe_helm_repository" {
  type        = string
  description = "The Helm repository URL for Terraform Enterprise chart (e.g., 'https://helm.releases.hashicorp.com')."
  default     = "https://helm.releases.hashicorp.com"
}

variable "tfe_namespace" {
  type        = string
  description = "namespace to place Terraform Enterprise in on cluster"
  default     = "tfe"

  validation {
    condition     = length(var.tfe_namespace) <= 59
    error_message = "var.tfe_namespace must be 59 characters or fewer. The OCP route hostname is constructed as 'tfe-<namespace>.<ingress-domain>' and DNS labels must not exceed 63 characters."
  }
}

variable "tfe_extra_env_vars" {
  description = "Additional plain (non-sensitive) environment variables to pass to Terraform Enterprise. Keys must be valid Terraform Enterprise configuration variable names (e.g. 'TFE_CAPACITY_CONCURRENCY'). See https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration for the full list. Merged with module-managed variables; caller values take precedence."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "tfe_organization" {
  type        = string
  description = "If set, the name of the Terraform Enterprise organization to create. If not set, the module will not create an organization."
  default     = "default"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,63}$", var.tfe_organization))
    error_message = "The Terraform Enterprise organization name must only contain letters, numbers, underscores (_), and hyphens (-), and must not exceed 63 characters."
  }
}

variable "add_to_catalog" {
  type        = bool
  description = "Whether to add this instance as an engine to your account's catalog settings. Defaults to true. MAY CONFLICT WITH EXISTING INSTANCES YOUR IN CATALOG SETTINGS."
  default     = false
}

variable "terraform_enterprise_engine_name" {
  type        = string
  description = "Name to give to the Terraform Enterprise engine in account catalog settings. Defaults to 'tfe-engine' if not set."
  nullable    = false
  default     = "tfe-engine"
  validation {
    condition     = var.terraform_enterprise_engine_name != ""
    error_message = "var.terraform_enterprise_engine_name cannot be set to an empty string."
  }
}

variable "enable_automatic_deployable_architecture_creation" {
  type        = bool
  description = "Whether to automatically create Deployable Architectures in associated private catalog from workspace."
  default     = false
}

variable "default_private_catalog_id" {
  type        = string
  description = "If `enable_deployable_architecture_creation` is true, specify the private catalog ID to create the Deployable Architectures in."
  default     = null

  validation {
    condition     = var.enable_automatic_deployable_architecture_creation != true ? true : var.default_private_catalog_id != null
    error_message = "Must specific a `default_private_catalog_id` if `enable_deployable_architecture_creation` is true."
  }
}

variable "terraform_engine_scopes" {
  type = list(object({
    name = string,
    type = string
  }))
  description = "List of scopes to auto-create deployable architectures from workspaces in the engine."
  default     = []
  nullable    = false
}

##############################################################################
# KMS
##############################################################################

variable "kms_instance_name" {
  type        = string
  description = "Name of KMS Key Protect instance to create. Default to tfe-kms-kp."
  default     = "tfe-kms-kp"
}

variable "kms_key_deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform. The KMS keys can not be force deleted by terraform when this value is set to 'true'. In order to delete with terraform the value must be set to 'false' and a terraform apply performed before the destroy is performed. The default is 'true'."
  default     = true
}

##############################################################################
# COS
##############################################################################

variable "existing_cos_instance_id" {
  type        = string
  description = "Existing COS instance to pass in. If set to `null`, a new instance will be created."
  default     = null
}

variable "cos_instance_name" {
  type        = string
  description = "Name of COS instance to create. Default to tfe-cos. If var.existing_cos_instance_id is not null this value is ignored. Null allowed only if var.existing_cos_instance_id is not null."
  default     = "tfe-cos"

  validation {
    condition     = var.existing_cos_instance_id == null && var.cos_instance_name == null ? false : true
    error_message = "var.existing_cos_instance_id and var.cos_instance_name cannot be both null."
  }
}

variable "cos_bucket_name" {
  type        = string
  nullable    = false
  description = "Name of the bucket to create in COS instance. Default to tfe-cos-bucket"
  default     = "tfe-cos-bucket"
}

variable "cos_retention_default" {
  description = "The number of days that an object can remain unmodified in an Object Storage bucket. For more details refer to terraform-ibm-modules cos documentation. Default to null to disable retention."
  type        = number
  default     = null
}

variable "cos_retention_maximum" {
  description = "he maximum number of days that an object can be kept unmodified in the bucket. For more details refer to terraform-ibm-modules cos documentation. Default to null to disable retention."
  type        = number
  default     = null
}

variable "cos_retention_minimum" {
  description = "The minimum number of days that an object must be kept unmodified in the bucket. For more details refer to terraform-ibm-modules cos documentation. Default to null to disable retention."
  type        = number
  default     = null
}

variable "cos_retention_permanent" {
  description = "Whether permanent retention status is enabled for the Object Storage bucket. For more details refer to terraform-ibm-modules cos documentation. Default to null to disable retention."
  type        = bool
  default     = null
}

##############################################################################
# PostGres
##############################################################################

variable "postgres_instance_name" {
  type        = string
  description = "Name of PostgreSQL instance to create. Default set to be `tfe-data-store`"
  default     = "tfe-data-store"
}

variable "postgres_deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform. This is not a property of the resource and does not prevent deletion outside of terraform. The database can not be deleted by terraform when this value is set to 'true'. In order to delete with terraform the value must be set to 'false' and a terraform apply performed before the destroy is performed. The default is 'true'."
  default     = true
}

variable "postgres_service_endpoints" {
  description = "Service endpoints for the PostgreSQL instance to deploy. Default is `public-and-private`"
  default     = "public-and-private"
  type        = string
  validation {
    condition     = contains(["private", "public-and-private"], var.postgres_service_endpoints)
    error_message = "Allowed values for var.postgres_service_endpoints are 'private' and 'public-and-private'"
  }
}

variable "postgres_vpe_enabled" {
  type        = bool
  description = "Enable VPE connection for the Postgres instance. Default is `false`. If true, a VPE gateway is created to the Postgres instance on its private endpoint. TFE is configured to connect to Postgres via the VPE on the private endpoint only if var.postgres_service_endpoints is set to \"private\"."
  default     = false
}

variable "postgres_vpe_service_endpoints" {
  type        = string
  description = "Service endpoints to use to create endpoint gateway to PostgreSQL instance."
  default     = "public"
  validation {
    condition     = contains(["public", "private"], var.postgres_vpe_service_endpoints)
    error_message = "The value of var.postgres_vpe_service_endpoints can be only public or private"
  }
}

variable "postgres_add_acl_rule" {
  type        = bool
  default     = true
  description = "Concatenate two rules to enable traffic to/from Postgres instance port to the VPC ACLs. If postgres_vpe_enabled is enabled the ACL rules will be configured VPC subnets CIDR as source and target, if postgres_vpe_enabled is disabled the ACL rules will use 0.0.0.0/0 as CIDR of Postgres instance references. Default true."
}

##############################################################################
# Redis
##############################################################################

variable "existing_redis_hostname" {
  type        = string
  description = "Hostname of an existing Redis instance to use. If not set, a new IBM Cloud Databases for Redis instance is provisioned. Default to null."
  default     = null
}

variable "existing_redis_port" {
  type        = number
  description = "Port of the existing redis instance. Default to null."
  default     = null

  validation {
    condition     = var.existing_redis_hostname != null ? var.existing_redis_port != null : true
    error_message = "If var.existing_redis_hostname is set, var.existing_redis_port must also be set."
  }
}

variable "existing_redis_username" {
  type        = string
  description = "Username for the existing redis instance. Default to null."
  default     = null
  sensitive   = true

  validation {
    condition     = var.existing_redis_hostname != null ? var.existing_redis_username != null : true
    error_message = "If var.existing_redis_hostname is set, var.existing_redis_username must also be set."
  }
}

variable "existing_redis_password_base64" {
  type        = string
  description = "Base64 encoded password for the existing redis instance. Default to null."
  default     = null
  sensitive   = true

  validation {
    condition     = var.existing_redis_hostname != null ? var.existing_redis_password_base64 != null : true
    error_message = "If var.existing_redis_hostname is set, var.existing_redis_password_base64 must also be set."
  }
}

variable "existing_redis_certificate_base64" {
  type        = string
  description = "Base64 encoded TLS certificate for the existing redis instance. Required for IBM Cloud Redis connections. Default to null."
  default     = null
  sensitive   = true

  validation {
    condition     = var.existing_redis_hostname != null ? var.existing_redis_certificate_base64 != null : true
    error_message = "If var.existing_redis_hostname is set, var.existing_redis_certificate_base64 must also be set for TLS connection."
  }
}

variable "redis_password_secret_name" {
  type        = string
  description = "The name of the Secrets Manager secret to store the redis password if var.existing_secrets_manager_crn is not null. Default to tfe_redis_password."
  default     = "tfe_redis_password"
  validation {
    condition     = var.existing_secrets_manager_crn == null ? true : (var.redis_password_secret_name != null && var.redis_password_secret_name != "" ? true : false)
    error_message = "If var.existing_secrets_manager_crn is not null var.redis_password_secret_name cannot be null or empty string."
  }
}

variable "redis_instance_name" {
  type        = string
  description = "Name of the Redis instance to create. Default to tfe-redis."
  default     = "tfe-redis"
  nullable    = false
}

variable "redis_version" {
  type        = string
  description = "Version of Redis to provision. Defaults to '8.2', which is the version tested with Terraform Enterprise. Must be in 'x.y' format (e.g. '7.2', '8.2'). Set to null to use the IBM Cloud preferred default."
  default     = "8.2"
}

variable "redis_member_host_flavor" {
  type        = string
  description = "Host flavor for Redis members. Default to multitenant."
  default     = "multitenant"
}

variable "redis_service_endpoints" {
  type        = string
  description = "Service endpoints for the Redis instance to deploy. Default is private."
  default     = "private"
  validation {
    condition     = contains(["private", "public-and-private"], var.redis_service_endpoints)
    error_message = "Allowed values for var.redis_service_endpoints are 'private' and 'public-and-private'"
  }
}

variable "redis_deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform. The Redis instance cannot be deleted by terraform when this value is set to 'true'. In order to delete with terraform the value must be set to 'false' and a terraform apply performed before the destroy is performed. The default is 'true'."
  default     = true
}

##############################################################################
# VPC/OCP
##############################################################################

variable "existing_vpc_id" {
  type        = string
  description = "The ID of the existing vpc. If not set, a new VPC will be created."
  default     = null
}

variable "existing_cluster_id" {
  type        = string
  description = "The ID of the existing cluster. If not set, a new cluster will be created."
  default     = null
}

variable "workers_per_zone" {
  type        = number
  description = "Number of worker nodes per zone in the default worker pool. Default is 2. Ignored when var.existing_cluster_id is set."
  default     = 2
  nullable    = false
}

variable "worker_node_flavor" {
  type        = string
  description = "The VPC machine type for worker nodes (e.g. 'bx2.4x16', 'bx2.8x32', 'bx2.16x64'). See https://cloud.ibm.com/docs/vpc?topic=vpc-profiles for available profiles. Default is 'bx2.4x16'. Ignored when var.existing_cluster_id is set."
  default     = "bx2.4x16"
  nullable    = false
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC to create. Default to tfe-vpc. If var.existing_vpc_id is not null this value is ignored. Null allowed only if var.existing_vpc_id is not null."
  default     = "tfe-vpc"
  validation {
    condition     = var.existing_vpc_id == null && var.vpc_name == null ? false : true
    error_message = "var.existing_vpc_id and var.vpc_name cannot be both null."
  }
}

variable "cluster_name" {
  type        = string
  description = "Name of the OCP cluster to create. Default to tfe-cluster. If var.existing_cluster_id is not null this value is ignored. Null allowed only if var.existing_cluster_id is not null."
  default     = "tfe-cluster"
  nullable    = false
  validation {
    condition     = var.existing_cluster_id == null && var.cluster_name == null ? false : true
    error_message = "var.existing_cluster_id and var.cluster_name cannot be both null."
  }
}

variable "ocp_version" {
  type        = string
  description = "Version of the OCP cluster to provision"
  default     = null
}

variable "ocp_entitlement" {
  type        = string
  description = "Value that is applied to the entitlements for OCP cluster provisioning"
  default     = null
}

variable "vpc_acl_rules" {
  description = "Custom ACLs rules to attach to the VPC ones"
  type = list(object({
    action          = string
    destination     = string
    direction       = string
    name            = string
    source          = string
    protocol        = optional(string)
    port_min        = optional(number)
    port_max        = optional(number)
    source_port_min = optional(number)
    source_port_max = optional(number)
    type            = optional(number)
    code            = optional(number)
  }))
  default = [
    {
      name            = "allow-all-inbound"
      action          = "allow"
      direction       = "inbound"
      source          = "0.0.0.0/0"
      destination     = "0.0.0.0/0"
      protocol        = null
      port_min        = null
      port_max        = null
      source_port_min = null
      source_port_max = null
      type            = null
      code            = null
    },
    {
      name            = "allow-all-outbound"
      action          = "allow"
      direction       = "outbound"
      source          = "0.0.0.0/0"
      destination     = "0.0.0.0/0"
      protocol        = null
      port_min        = null
      port_max        = null
      source_port_min = null
      source_port_max = null
      type            = null
      code            = null
    }
  ]
}

variable "subnets_zones_cidr" {
  description = "Map of zone name (key) and cidr to use in the zone (value)"
  type        = map(string)
  default = {
    "zone-1" = "10.10.10.0/24"
    "zone-2" = "10.20.10.0/24"
    "zone-3" = "10.30.10.0/24"
  }
}

##############################################################################
# Secrets Manager
##############################################################################

variable "existing_secrets_manager_crn" {
  type        = string
  description = "The CRN of the existing Secrets Manager instance. If not set, secrets will not be stored in a Secrets Manager instance."
  default     = null

  validation {
    condition = anytrue([
      var.existing_secrets_manager_crn == null,
      can(regex("^crn:v\\d:(.*:){2}secrets-manager:(.*:)([aos]\\/[\\w_\\-]+):[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}::$", var.existing_secrets_manager_crn))
    ])
    error_message = "The value provided for 'existing_secrets_manager_crn' is not valid."
  }
}

variable "existing_secrets_manager_secret_group_id" {
  type        = string
  description = "The existing secrets group ID to store secrets in. If not set, secrets will be stored in `var.secrets_manager_secret_group_name` secret group."
  default     = null

  validation {
    condition = (
      !(var.existing_secrets_manager_crn == null &&
      var.existing_secrets_manager_secret_group_id != null)
    )
    error_message = "`secrets_manager_secret_group_id` is not required when `secrets_manager_crn` is not specified."
  }

  validation {
    condition = anytrue([
      var.existing_secrets_manager_secret_group_id == null,
      var.existing_secrets_manager_secret_group_id == "default",
      can(regex("^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", var.existing_secrets_manager_secret_group_id))
    ])
    error_message = "The value provided for 'existing_secrets_manager_secret_group_id' is not valid."
  }
}

variable "secrets_manager_secret_group_name" {
  type        = string
  description = "The secrets group name to create to store secrets in var.existing_secrets_manager_crn if var.existing_secrets_manager_secret_group_id is null."
  default     = "tfe-secrets-group"
  validation {
    condition     = var.existing_secrets_manager_secret_group_id != null || var.secrets_manager_secret_group_name != null
    error_message = "var.secrets_manager_secret_group_name and var.existing_secrets_manager_secret_group_id cannot be both null."
  }
}

##############################################################################
# Terraform Enterprise secondary hostname support
##############################################################################

variable "existing_cis_instance_name" {
  type        = string
  description = "Existing IBM Cloud Internet Service instance name providing the support for the base domain of Terraform Enterprise instance secondary hostname. It is required to configure a Terraform Enterprise instance secondary hostname. Default to null."
  default     = null
}

variable "existing_cis_instance_resource_group_id" {
  description = "Existing Resource Group ID for the existing IBM Cloud Internet Service instance. It is required to configure a Terraform Enterprise instance secondary hostname. Default to null."
  type        = string
  default     = null
}

variable "existing_cis_instance_domain" {
  description = "The base domain configured on existing IBM Cloud Internet Service instance to use as domain for the Terraform Enterprise instance secondary hostname FQDN. It is required to configure the Terraform Enterprise instance secondary hostname. Default to null."
  type        = string
  default     = null
}

variable "tfe_secondary_host" {
  description = "The Terraform Enterprise secondary host name to concatenate with the var.existing_cis_instance_domain for the Terraform Enterprise instance secondary hostname FQDN. Default to null."
  type        = string
  default     = null
  validation {
    condition     = var.tfe_secondary_host == null || (var.tfe_secondary_host != null && var.existing_cis_instance_name != null && var.existing_cis_instance_resource_group_id != null && var.existing_cis_instance_domain != null && var.tfe_secondary_hostname_existing_secret_crn != null)
    error_message = "If var.tfe_secondary_host all the inputs var.existing_cis_instance_name var.existing_cis_instance_resource_group_id var.existing_cis_instance_domain and var.tfe_secondary_hostname_existing_secret_crn must be not null."
  }
}

variable "create_tfe_secondary_host_on_cis" {
  description = "Flag to create the host entry for the Terraform Enterprise secondary hostname on existing IBM Cloud Internet Service instance for the base domain provided through var.existing_cis_instance_domain. If enabled a CNAME entry is created on the DNS configuration mapping the default Terraform Enterprise instance route. Default to false."
  type        = bool
  default     = false
  validation {
    condition     = (var.create_tfe_secondary_host_on_cis == true && var.tfe_secondary_host != null) || var.create_tfe_secondary_host_on_cis == false
    error_message = "If var.create_tfe_secondary_host_on_cis is true the value of var.tfe_secondary_host cannot be null."
  }
}

variable "tfe_secondary_hostname_existing_secret_crn" {
  description = "CRN of the existing secret storing the TLS certificate for the secondary hostname FQDN of the Terraform Enterprise instance. It is required to configure the Terraform Enterprise secondary hostname. Default to null."
  type        = string
  default     = null
}

variable "tfe_secondary_hostname_secret_name" {
  description = "The secret name to be used to store the TLS certificate on the OCP cluster for the secondary hostname FQDN of the Terraform Enterprise instance. Default to null. If null and the secondary Terraform Enterprise hostname is provided the secret is named 'terraform-enterprise-certificates-secondary'."
  type        = string
  default     = null
}
