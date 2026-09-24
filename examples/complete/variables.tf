########################################################################################################################
# Input Variables
########################################################################################################################

variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud api key"
  sensitive   = true
}

variable "ibmcloud_provider_visibility" {
  type        = string
  description = "The IBM Cloud provider visibility setting"
  default     = "public"
}

variable "prefix" {
  type        = string
  description = "Prefix for name of all resource created by this example"

  validation {
    error_message = "var.prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition = (var.prefix == null || var.prefix == "" ? true :
      alltrue([
        can(regex("^[a-z][-a-z0-9]*[a-z0-9]$", var.prefix)),
        length(regexall("--", var.prefix)) == 0
      ])
    )
  }
  default = "tfe-complete"
}

variable "region" {
  type        = string
  description = "Region where resources are created"
  default     = "us-south"
}

variable "existing_resource_group_name" {
  type        = string
  description = "An existing resource group name to provision resources in, if unset a new resource group will be created"
  default     = null
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = []
}

variable "tfe_license" {
  type        = string
  description = "The license key for Terraform Enterprise"
  default     = null
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
  description = "The container image registry to pull the Terraform Enterprise image from."
  default     = "images.releases.hashicorp.com/hashicorp/terraform-enterprise"
  nullable    = false
}

variable "tfe_image_pull_secret_username" {
  type        = string
  description = "The username used to authenticate with the image registry for the pull secret."
  default     = "terraform"
  nullable    = false
}

# renovate: datasource=helm depName=terraform-enterprise registryUrl=https://helm.releases.hashicorp.com
variable "tfe_helm_chart_version" {
  type        = string
  description = "The version of the Terraform Enterprise Helm chart to use. Check on https://github.com/hashicorp/terraform-enterprise-helm/blob/main/CHANGELOG.md for available versions."
  default     = "2.0.5"
}

variable "tfe_helm_repository" {
  type        = string
  description = "The Helm repository URL for Terraform Enterprise chart."
  default     = "https://helm.releases.hashicorp.com"
}

variable "tfe_encryption_password" {
  type        = string
  description = "The encryption password used by Terraform Enterprise to protect sensitive data at rest. Must be kept secret and consistent across upgrades."
  sensitive   = true
}

variable "admin_username" {
  type        = string
  description = "The user name of the Terraform Enterprise admin user"
  default     = "admin"
}

variable "admin_email" {
  type        = string
  description = "The email address of the Terraform Enterprise admin user"
  default     = "test@example.com"
}

variable "admin_password" {
  type        = string
  description = "The password for the Terraform Enterprise admin user. 10 char minimum"
  sensitive   = true
}

variable "tfe_organization_name" {
  type        = string
  description = "If set, the name of the Terraform Enterprise organization to create. If not set, the module will not create an organization."
  default     = "default"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,63}$", var.tfe_organization_name))
    error_message = "The Terraform Enterprise organization name must only contain letters, numbers, underscores (_), and hyphens (-), and must not exceed 63 characters."
  }
}

variable "add_to_catalog" {
  type        = bool
  description = "Whether to add this instance as an engine to your account's catalog settings. Defaults to true. MAY CONFLICT WITH EXISTING INSTANCES YOUR IN CATALOG SETTINGS."
  default     = false
}

variable "postgres_deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform. This is not a property of the resource and does not prevent deletion outside of terraform. The database can not be deleted by terraform when this value is set to 'true'. In order to delete with terraform the value must be set to 'false' and a terraform apply performed before the destroy is performed. The default is 'true'."
  default     = true
}

variable "redis_deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform. The Redis instance cannot be deleted by terraform when this value is set to 'true'. In order to delete with terraform the value must be set to 'false' and a terraform apply performed before the destroy is performed. The default is 'true'."
  default     = false
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
  description = "Enable VPE connection for the Postgres instance. Default is `false`. If true, a VPE gateway is created to the Postgres instance and TFE is configured with the VPE endpoint."
  default     = false
}

variable "postgres_vpe_service_endpoints" {
  type        = string
  description = "Service endpoints to use to create endpoint gateway to PostgreSQL instance. Default to 'public'."
  default     = "public"
  validation {
    condition     = contains(["public", "private"], var.postgres_vpe_service_endpoints)
    error_message = "Allowed values for var.postgres_vpe_service_endpoints are 'public' and 'private'"
  }
}

variable "kms_key_deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform. The KMS keys can not be force deleted by terraform when this value is set to 'true'. In order to delete with terraform the value must be set to 'false' and a terraform apply performed before the destroy is performed. The default is 'true'."
  default     = true
}

variable "vpc_acl_rules" {
  description = "Custom ACLs rules to attach to the VPC ones. Default opens HTTPs traffic to VPC subnets."
  type = list(object({
    action          = string
    before          = optional(string, null)
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
    # rules needed to access tfe dashboard on public route
    {
      name            = "allow-https-inbound-zone-1"
      action          = "allow"
      direction       = "inbound"
      source          = "0.0.0.0/0"
      destination     = "10.10.10.0/24"
      protocol        = "tcp"
      source_port_min = 1
      source_port_max = 65535
      port_min        = 443
      port_max        = 443
      type            = null
      code            = null
    },
    {
      name            = "allow-https-outbound-zone-1"
      action          = "allow"
      direction       = "outbound"
      source          = "10.10.10.0/24"
      destination     = "0.0.0.0/0"
      protocol        = "tcp"
      source_port_min = 443
      source_port_max = 443
      port_min        = 1
      port_max        = 65535
      type            = null
      code            = null
    },
    {
      name            = "allow-https-inbound-zone-2"
      action          = "allow"
      direction       = "inbound"
      source          = "0.0.0.0/0"
      destination     = "10.10.20.0/24"
      protocol        = "tcp"
      source_port_min = 1
      source_port_max = 65535
      port_min        = 443
      port_max        = 443
      type            = null
      code            = null
    },
    {
      name            = "allow-https-outbound-zone-2"
      action          = "allow"
      direction       = "outbound"
      source          = "10.20.10.0/24"
      destination     = "0.0.0.0/0"
      protocol        = "tcp"
      source_port_min = 443
      source_port_max = 443
      port_min        = 1
      port_max        = 65535
      type            = null
      code            = null
    },
    {
      name            = "allow-https-inbound-zone-3"
      action          = "allow"
      direction       = "inbound"
      source          = "0.0.0.0/0"
      destination     = "10.30.10.0/24"
      protocol        = "tcp"
      source_port_min = 1
      source_port_max = 65535
      port_min        = 443
      port_max        = 443
      type            = null
      code            = null
    },
    {
      name            = "allow-https-outbound-zone-3"
      action          = "allow"
      direction       = "outbound"
      source          = "10.30.10.0/24"
      destination     = "0.0.0.0/0"
      protocol        = "tcp"
      source_port_min = 443
      source_port_max = 443
      port_min        = 1
      port_max        = 65535
      type            = null
      code            = null
    },
    # rules needed to pull container images from external registries
    {
      name            = "allow-https-outbound-for-images-zone-1"
      action          = "allow"
      direction       = "outbound"
      source          = "10.10.10.0/24"
      destination     = "0.0.0.0/0"
      protocol        = "tcp"
      source_port_min = 1
      source_port_max = 65535
      port_min        = 443
      port_max        = 443
      type            = null
      code            = null
    },
    {
      name            = "allow-https-outbound-for-images-zone-2"
      action          = "allow"
      direction       = "outbound"
      source          = "10.20.10.0/24"
      destination     = "0.0.0.0/0"
      protocol        = "tcp"
      source_port_min = 1
      source_port_max = 65535
      port_min        = 443
      port_max        = 443
      type            = null
      code            = null
    },
    {
      name            = "allow-https-outbound-for-images-zone-3"
      action          = "allow"
      direction       = "outbound"
      source          = "10.30.10.0/24"
      destination     = "0.0.0.0/0"
      protocol        = "tcp"
      source_port_min = 1
      source_port_max = 65535
      port_min        = 443
      port_max        = 443
      type            = null
      code            = null
    },
    {
      name            = "allow-https-inbound-for-images-zone-1"
      action          = "allow"
      direction       = "inbound"
      source          = "0.0.0.0/0"
      destination     = "10.10.10.0/24"
      protocol        = "tcp"
      source_port_min = 443
      source_port_max = 443
      port_min        = 1
      port_max        = 65535
      type            = null
      code            = null
    },
    {
      name            = "allow-https-inbound-for-images-zone-2"
      action          = "allow"
      direction       = "inbound"
      source          = "0.0.0.0/0"
      destination     = "10.20.10.0/24"
      protocol        = "tcp"
      source_port_min = 443
      source_port_max = 443
      port_min        = 1
      port_max        = 65535
      type            = null
      code            = null
    },
    {
      name            = "allow-https-inbound-for-images-zone-3"
      action          = "allow"
      direction       = "inbound"
      source          = "0.0.0.0/0"
      destination     = "10.30.10.0/24"
      protocol        = "tcp"
      source_port_min = 443
      source_port_max = 443
      port_min        = 1
      port_max        = 65535
      type            = null
      code            = null
    }
  ]
}

variable "postgres_add_acl_rule" {
  type        = bool
  default     = true
  description = "Concatenate two rules to enable traffic to/from Postgres instance port to the VPC ACLs. If postgres_vpe_enabled is enabled the ACL rules will be configured VPC subnets CIDR as source and target, if postgres_vpe_enabled is disabled the ACL rules will use 0.0.0.0/0 as CIDR of Postgres instance references. Default true."
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

variable "secrets_manager_crn" {
  type        = string
  description = "The CRN of the existing Secrets Manager instance. If not set, secrets will not be stored in a Secrets Manager instance."
  default     = null
}

variable "secrets_manager_secret_group_id" {
  type        = string
  description = "The existing secrets group ID to store secrets in. If not set, secrets will be stored in `<var.prefix>` secret group."
  default     = null
}

variable "tfe_license_secret_crn" {
  type        = string
  description = "The CRN of the Secrets Manager secret containing the license key for Terraform Enterprise"
  default     = null
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
