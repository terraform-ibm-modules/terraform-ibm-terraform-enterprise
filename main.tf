########################################################################################################################
# Resource Group
########################################################################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.4.0"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.existing_resource_group_name == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.existing_resource_group_name
}

##############################################################################
# Create Cloud Object Storage instance and a bucket
##############################################################################

module "cos" {
  source                   = "terraform-ibm-modules/cos/ibm"
  version                  = "10.5.10"
  resource_group_id        = module.resource_group.resource_group_id
  region                   = var.region
  create_cos_instance      = var.existing_cos_instance_id != null ? false : true
  existing_cos_instance_id = var.existing_cos_instance_id
  cos_instance_name        = var.cos_instance_name != null ? var.cos_instance_name : "${var.prefix}-tfe"
  cos_tags                 = var.resource_tags
  bucket_name              = var.cos_bucket_name != null ? var.cos_bucket_name : "${var.prefix}-tfe-bucket"
  add_bucket_name_suffix   = true
  create_cos_bucket        = true
  retention_enabled        = var.cos_retention # disable retention for test environments - enable for stage/prod
  kms_encryption_enabled   = false
  resource_keys = [
    {
      name                      = "tfe-credentials"
      generate_hmac_credentials = true
      role                      = "Writer"
    }
  ]
}


########################################################################################################################
# VPC
########################################################################################################################

module "ocp_vpc" {
  source            = "./modules/ocp-vpc"
  region            = var.region
  prefix            = var.prefix
  resource_group_id = module.resource_group.resource_group_id
  resource_tags     = var.resource_tags
  access_tags       = var.access_tags
  ocp_version       = var.ocp_version
  ocp_entitlement   = var.ocp_entitlement
  existing_vpc_id   = var.existing_vpc_id
}

########################################################################################################################
# ICD Postgres
########################################################################################################################

module "icd_postgres" {
  source             = "terraform-ibm-modules/icd-postgresql/ibm"
  version            = "4.3.0"
  resource_group_id  = module.resource_group.resource_group_id
  name               = var.postgres_instance_name != null ? var.postgres_instance_name : "${var.prefix}-data-store"
  postgresql_version = "16" # TFE supports up to Postgres 16 (not 17)
  region             = var.region
  service_endpoints  = "public-and-private"
  member_host_flavor = "multitenant"
  service_credential_names = {
    "tfe" : "Operator"
  }
  deletion_protection = var.postgres_deletion_protection
}

########################################################################################################################
# Redis
########################################################################################################################

module "redis" {
  count  = var.redis_host_name == null ? 1 : 0
  source = "./modules/redis"
}

locals {
  redis_host        = var.redis_host_name != null ? var.redis_host_name : module.redis[0].redis_host
  redis_pass_base64 = var.redis_password_base64 != null ? var.redis_password_base64 : module.redis[0].redis_password_base64
}

########################################################################################################################
# TFE
########################################################################################################################

module "tfe_install" {
  source                    = "./modules/tfe-install"
  cluster_id                = module.ocp_vpc.cluster_id
  cluster_resource_group_id = module.resource_group.resource_group_id
  namespace                 = var.tfe_namespace
  tfe_license               = var.tfe_license
  tfe_database_host         = "${module.icd_postgres.hostname}:${module.icd_postgres.port}"
  tfe_database_user         = module.icd_postgres.service_credentials_object.credentials["tfe"].username
  tfe_database_password     = module.icd_postgres.service_credentials_object.credentials["tfe"].password

  tfe_s3_bucket     = module.cos.bucket_name
  tfe_s3_region     = var.region
  tfe_s3_access_key = module.cos.resource_keys["tfe-credentials"].credentials["cos_hmac_keys.access_key_id"]
  tfe_s3_secret_key = module.cos.resource_keys["tfe-credentials"].credentials["cos_hmac_keys.secret_access_key"]
  tfe_s3_endpoint   = module.cos.s3_endpoint_public

  tfe_redis_host     = local.redis_host
  tfe_redis_password = local.redis_pass_base64

  admin_username = var.admin_username
  admin_password = var.admin_password
  admin_email    = var.admin_email

  tfe_organization = var.tfe_organization
}

########################################################################################################################
# Connect to Catalog Management
########################################################################################################################

locals {
  terraform_enterprise_engine_name = var.terraform_enterprise_engine_name != null ? var.terraform_enterprise_engine_name : "${var.prefix}-tfe"
}

resource "ibm_cm_account" "cm_account_instance" {
  count = var.add_to_catalog ? 1 : 0
  terraform_engines {
    name            = local.terraform_enterprise_engine_name
    type            = "terraform-enterprise"
    public_endpoint = module.tfe_install.tfe_console_url
    # private_endpoint = "<private_endpoint>"
    api_token = module.tfe_install.token
    da_creation {
      enabled                    = var.enable_automatic_deployable_architecture_creation
      default_private_catalog_id = var.default_private_catalog_id
      polling_info {
        dynamic "scopes" {
          for_each = var.terraform_engine_scopes
          content {
            name = scopes.value.name
            type = scopes.value.type
          }
        }
      }
    }
  }
}

########################################################################################################################
# Store Credentials in Secrets Manager
########################################################################################################################

module "secrets_manager_crn" {
  count   = var.secrets_manager_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.3.0"
  crn     = var.secrets_manager_crn
}

module "secrets_manager_secret_group" {
  count                    = var.secrets_manager_crn != null && var.secrets_manager_secret_group_id == null ? 1 : 0
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.3.13"
  secret_group_name        = var.prefix
  secret_group_description = "Secret group for storing secrets created by the Terraform Enterprise Deployable Architecture."
  secrets_manager_guid     = module.secrets_manager_crn[0].service_instance
  region                   = module.secrets_manager_crn[0].region
}

locals {
  secret_group_id = var.secrets_manager_crn == null ? null : var.secrets_manager_secret_group_id != null ? var.secrets_manager_secret_group_id : module.secrets_manager_secret_group[0].secret_group_id
}

module "instance_token_secret" {
  count                   = var.secrets_manager_crn != null ? 1 : 0
  source                  = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                 = "1.7.0"
  region                  = module.secrets_manager_crn[0].region
  secrets_manager_guid    = module.secrets_manager_crn[0].service_instance
  secret_group_id         = local.secret_group_id
  secret_name             = "${var.prefix}-terraform-enterprise-token"
  secret_description      = "Token for the Terraform Enterprise instance."
  secret_type             = "arbitrary"
  secret_payload_password = module.tfe_install.token
}

module "redis_password_secret" {
  count                   = var.secrets_manager_crn != null ? 1 : 0
  source                  = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                 = "1.7.0"
  region                  = module.secrets_manager_crn[0].region
  secrets_manager_guid    = module.secrets_manager_crn[0].service_instance
  secret_group_id         = local.secret_group_id
  secret_name             = "${var.prefix}-terraform-enterprise-redis-password"
  secret_description      = "Password for the Terraform Enterprise redis instance."
  secret_type             = "arbitrary"
  secret_payload_password = local.redis_pass_base64
}
