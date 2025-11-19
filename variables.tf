########################################################################################################################
# Input Variables
########################################################################################################################

# variable "ibmcloud_api_key" {
#   type        = string
#   description = "The IBM Cloud api key"
#   sensitive   = true
# }

variable "prefix" {
  type        = string
  description = "Prefix for name of all resource created by this example"
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "region" {
  type        = string
  description = "Region where resources are created"
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

variable "access_tags" {
  type        = list(string)
  description = "Optional list of access tags to be added to created resources"
  default     = []
}

##############################################################################
# TFE
##############################################################################

variable "tfe_license" {
  type        = string
  description = "The license key for TFE"
  sensitive   = true
}

variable "admin_username" {
  description = "The user name of the TFE admin user"
  type        = string
}

variable "admin_email" {
  description = "The email address of the TFE admin user"
  type        = string
}

variable "admin_password" {
  description = "The password for the TFE admin user"
  type        = string
  sensitive   = true
}

variable "tfe_namespace" {
  description = "namespace to place TFE in on cluster"
  type        = string
  default     = "tfe"
}

variable "tfe_organization" {
  description = "If set, the name of the TFE organization to create. If not set, the module will not create an organization."
  type        = string
  default     = "default"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,63}$", var.tfe_organization))
    error_message = "The TFE organization name must only contain letters, numbers, underscores (_), and hyphens (-), and must not exceed 63 characters."
  }
}


variable "add_to_catalog" {
  description = "Whether to add this instance as an engine to your account's catalog settings. Defaults to true. MAY CONFLICT WITH EXISTING INSTANCES YOUR IN CATALOG SETTINGS."
  type        = bool
  default     = true
}

variable "terraform_enterprise_engine_name" {
  type        = string
  description = "Name to give to the Terraform Enterprise engine in account catalog settings. Defaults to '{prefix}-tfe' if not set."
  default     = null
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
# COS
##############################################################################

variable "existing_cos_instance_id" {
  description = "Existing COS instance to pass in. If set to `null`, a new instance will be created."
  type        = string
  default     = null
}

variable "cos_instance_name" {
  description = "Name of COS instance to create. If set to `null`, name will be `{prefix}-tfe`"
  type        = string
  default     = null
  validation {
    condition     = var.cos_instance_name == null || var.existing_cos_instance_id == null
    error_message = "If var.existing_cos_instance_id is set, a new COS instance will not be created."
  }
}

variable "cos_bucket_name" {
  description = "Name of the bucket to create in COS instance. If set to `null`, name will be `{prefix}-tfe-bucket`"
  type        = string
  default     = null
}

variable "cos_retention" {
  description = "Whether retention for the Object Storage bucket is enabled. Enable for staging and prod environments."
  type        = bool
  default     = false
}

##############################################################################
# PostGres
##############################################################################

variable "postgres_instance_name" {
  description = "Name of postgres instance to create. If set to `null`, name will be `{prefix}-data-store`"
  type        = string
  default     = null
}

variable "postgres_deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform. This is not a property of the resource and does not prevent deletion outside of terraform. The database can not be deleted by terraform when this value is set to 'true'. In order to delete with terraform the value must be set to 'false' and a terraform apply performed before the destroy is performed. The default is 'true'."
  default     = true
}

##############################################################################
# Redis
##############################################################################

variable "redis_host_name" {
  description = "Hostname of redis instance on cluster. If set to `null`, a new redis instance will be provisioned"
  type        = string
  default     = null
}

variable "redis_password_base64" {
  description = "password for redis instance (base64 encoded)"
  type        = string
  sensitive   = true
  default     = null
  validation {
    condition     = var.redis_host_name != null ? var.redis_password_base64 != null : true
    error_message = "If var.redis_host_name is set, var.redis_password_base64 must also be set."
  }
}

##############################################################################
# VPC/OCP
##############################################################################

variable "existing_vpc_id" {
  description = "The ID of the existing vpc. If not set, a new VPC will be created."
  type        = string
  default     = null
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

##############################################################################
# Secrets Manager
##############################################################################

variable "secrets_manager_crn" {
  description = "The CRN of the existing Secrets Manager instance. If not set, secrets will not be stored in a Secrets Manager instance."
  type        = string
  default     = null

  validation {
    condition = anytrue([
      var.secrets_manager_crn == null,
      can(regex("^crn:v\\d:(.*:){2}secrets-manager:(.*:)([aos]\\/[\\w_\\-]+):[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}::$", var.secrets_manager_crn))
    ])
    error_message = "The value provided for 'secrets_manager_crn' is not valid."
  }
}

variable "secrets_manager_secret_group_id" {
  description = "The existing secrets group ID to store secrets in. If not set, secrets will be stored in `<var.prefix>` secret group."
  type        = string
  default     = null

  validation {
    condition = anytrue([
      var.secrets_manager_secret_group_id == null,
      var.secrets_manager_secret_group_id == "default",
      can(regex("^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", var.secrets_manager_secret_group_id))
    ])
    error_message = "The value provided for 'secrets_manager_secret_group_id' is not valid."
  }

  validation {
    condition = (
      !(var.secrets_manager_crn == null &&
      var.secrets_manager_secret_group_id != null)
    )
    error_message = "`secrets_manager_secret_group_id` is not required when `secrets_manager_crn` is not specified."
  }
}
