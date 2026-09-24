##############################################################################
# Create Key Protect KMS instance and keys
##############################################################################

locals {
  force_delete = var.kms_key_deletion_protection ? false : true
}

module "key_protect_all_inclusive" {
  source                    = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                   = "5.6.5"
  resource_group_id         = var.resource_group_id
  key_protect_instance_name = var.kms_instance_name
  region                    = var.region
  resource_tags             = var.resource_tags
  access_tags               = var.access_tags
  keys = [
    # Create one new Key Ring with multiple new Keys in it
    {
      key_ring_name = "terraform-enterprise"
      keys = [
        {
          key_name     = "terraform-enterprise-cos"
          force_delete = local.force_delete
        },
        {
          key_name     = "terraform-enterprise-postgresql"
          force_delete = local.force_delete
        },
        {
          key_name     = "terraform-enterprise-postgresql-backup"
          force_delete = local.force_delete
        },
        {
          key_name     = "terraform-enterprise-redis"
          force_delete = local.force_delete
        },
        {
          key_name     = "terraform-enterprise-redis-backup"
          force_delete = local.force_delete
        },
        {
          key_name     = "terraform-enterprise-vsi-volume-key"
          force_delete = local.force_delete
        }
      ]
    }
  ]
}

# Local setup for VSI disk encryption
locals {
  kms_config = {
    crk             = module.key_protect_all_inclusive.keys["terraform-enterprise.terraform-enterprise-vsi-volume-key"].key_id
    kms_instance_id = module.key_protect_all_inclusive.kms_guid
    kms_account_id  = module.key_protect_all_inclusive.kms_account_id
  }
}


##############################################################################
# Create Cloud Object Storage instance and a bucket
##############################################################################

module "cos" {
  source                   = "terraform-ibm-modules/cos/ibm"
  version                  = "10.17.5"
  resource_group_id        = var.resource_group_id
  region                   = var.region
  create_cos_instance      = var.existing_cos_instance_id != null ? false : true
  existing_cos_instance_id = var.existing_cos_instance_id
  cos_instance_name        = var.cos_instance_name
  resource_tags            = var.resource_tags
  bucket_name              = var.cos_bucket_name
  retention_default        = var.cos_retention_default
  retention_maximum        = var.cos_retention_maximum
  retention_minimum        = var.cos_retention_minimum
  retention_permanent      = var.cos_retention_permanent
  add_bucket_name_suffix   = true
  create_cos_bucket        = true
  kms_encryption_enabled   = true
  kms_key_crn              = module.key_protect_all_inclusive.keys["terraform-enterprise.terraform-enterprise-cos"].crn
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
  source              = "./modules/ocp-vpc"
  region              = var.region
  resource_group_id   = var.resource_group_id
  resource_tags       = var.resource_tags
  access_tags         = var.access_tags
  ocp_version         = var.ocp_version
  ocp_entitlement     = var.ocp_entitlement
  existing_vpc_id     = var.existing_vpc_id
  existing_cluster_id = var.existing_cluster_id
  vpc_name            = var.vpc_name
  cluster_name        = var.cluster_name
  vpc_acl_rules       = local.final_acl_rules
  subnets_zones_cidr  = var.subnets_zones_cidr
  kms_config          = local.kms_config
  workers_per_zone    = var.workers_per_zone
  worker_node_flavor  = var.worker_node_flavor
}

########################################################################################################################
# ICD Postgres
########################################################################################################################

module "icd_postgres" {
  source                       = "terraform-ibm-modules/icd-postgresql/ibm"
  version                      = "4.15.2"
  resource_group_id            = var.resource_group_id
  name                         = var.postgres_instance_name
  postgresql_version           = "16" # TFE supports up to Postgres 16 (not 17)
  region                       = var.region
  service_endpoints            = var.postgres_service_endpoints
  member_host_flavor           = "multitenant"
  use_ibm_owned_encryption_key = false
  use_same_kms_key_for_backups = false
  kms_key_crn                  = module.key_protect_all_inclusive.keys["terraform-enterprise.terraform-enterprise-postgresql"].crn
  backup_encryption_key_crn    = module.key_protect_all_inclusive.keys["terraform-enterprise.terraform-enterprise-postgresql-backup"].crn
  service_credential_names = [
    {
      "name" : "tfe",
      "role" : "Administrator"
    }
  ]
  deletion_protection = var.postgres_deletion_protection
}

########################################################################################################################
# VPC
########################################################################################################################

# defining ACL rules to allow traffic to/from the ICD Postgres instance based on the selected service endpoints and VPE configuration
locals {

  postgres_public_acl_rules = flatten([
    for subnet, cidr in var.subnets_zones_cidr :
    concat(
      [
        {
          name            = "allow-postgres-outbound-${subnet}"
          action          = "allow"
          direction       = "outbound"
          source          = cidr
          destination     = "0.0.0.0/0"
          protocol        = "tcp"
          source_port_min = 1
          source_port_max = 65535
          port_min        = module.icd_postgres.port
          port_max        = module.icd_postgres.port
          type            = null
          code            = null
        }
      ],
      [
        {
          name            = "allow-postgres-inbound-${subnet}"
          action          = "allow"
          direction       = "inbound"
          source          = "0.0.0.0/0"
          destination     = cidr
          protocol        = "tcp"
          source_port_min = module.icd_postgres.port
          source_port_max = module.icd_postgres.port
          port_min        = 1
          port_max        = 65535
          type            = null
          code            = null
        }
      ]
    )
    ]
  )

  # ACL rules allowing traffic from/to the subnet CIDRs when VPE is enabled
  postgres_vpe_acl_rules = flatten([
    for subnet, cidr in var.subnets_zones_cidr : [
      {
        name            = "allow-postgres-outbound-to-vpe-${subnet}"
        action          = "allow"
        direction       = "outbound"
        source          = cidr
        destination     = cidr
        protocol        = "tcp"
        source_port_min = 1
        source_port_max = 65535
        port_min        = module.icd_postgres.port
        port_max        = module.icd_postgres.port
        type            = null
        code            = null
      },
      {
        name            = "allow-postgres-inbound-from-vpe-${subnet}"
        action          = "allow"
        direction       = "inbound"
        source          = cidr
        destination     = cidr
        protocol        = "tcp"
        source_port_min = module.icd_postgres.port
        source_port_max = module.icd_postgres.port
        port_min        = 1
        port_max        = 65535
        type            = null
        code            = null
      }
    ]
  ])

  # if postgres_add_acl_rule is true, concatenate the appropriate postgres ACL rules to the VPC ACL rules
  # if VPE connections is enabled (var.postgres_vpe_enabled flag true) and postgres_service_endpoints is "private", use the VPE ACL rules
  # otherwise use the public ACL rules
  # the same for postgres_service_endpoints "public-and-private" as we enforce private endpoint as postgresql hostname
  final_acl_rules = var.postgres_add_acl_rule ? (
    var.postgres_vpe_enabled == true && (var.postgres_service_endpoints == "private" || var.postgres_service_endpoints == "public-and-private") ?
    concat(var.vpc_acl_rules, local.postgres_vpe_acl_rules) :
    concat(var.vpc_acl_rules, local.postgres_public_acl_rules)
  ) : var.vpc_acl_rules
}

locals {
  sleep_before_creating_vpe = "300s"
}

# in order to avoid to fail as service is not found we need to sleep for 5 minutes before creating the VPE
resource "time_sleep" "wait_before_creating_vpe" {
  depends_on      = [module.ocp_vpc]
  count           = var.postgres_vpe_enabled == true ? 1 : 0
  create_duration = local.sleep_before_creating_vpe
}

module "icd_postgres_vpe" {
  depends_on = [time_sleep.wait_before_creating_vpe]
  count      = var.postgres_vpe_enabled ? 1 : 0
  source     = "terraform-ibm-modules/vpe-gateway/ibm"
  version    = "5.3.5"
  region     = var.region
  cloud_service_by_crn = [
    {
      crn          = (module.icd_postgres.crn)
      service_name = "postgresql"
    }
  ]
  service_endpoints = var.postgres_vpe_service_endpoints
  vpc_name          = module.ocp_vpc.vpc_name
  vpc_id            = module.ocp_vpc.vpc_id
  subnet_zone_list  = module.ocp_vpc.vpc_subnet_zone_list
  resource_group_id = var.resource_group_id
}


# attach rules to the VPC default security group to enable traffic from the OCP cluster's workers to the ICD Postgres instance
# if the VPE gateway to postgres is enabled, restrict access to the subnet CIDRs, otherwise allow from anywhere
resource "ibm_is_security_group_rule" "vpc_kubecluster_sg_rule" {
  for_each = {
    for subnet in module.ocp_vpc.vpc_subnet_zone_list :
    "${subnet.name}_${subnet.zone}" => {
      id   = subnet.id
      zone = subnet.zone
      cidr = subnet.cidr
    }
  }
  group     = module.ocp_vpc.vpc_default_security_group
  direction = "inbound"
  local     = var.postgres_vpe_enabled == true ? each.value.cidr : "0.0.0.0/0"
  remote    = module.ocp_vpc.kube_cluster_sg.id
  protocol  = "tcp"
  port_min  = module.icd_postgres.port
  port_max  = module.icd_postgres.port
}

########################################################################################################################
# Redis
########################################################################################################################

module "redis" {
  count                     = var.existing_redis_hostname == null ? 1 : 0
  source                    = "./modules/redis"
  resource_group_id         = var.resource_group_id
  redis_instance_name       = var.redis_instance_name
  region                    = var.region
  redis_version             = var.redis_version
  redis_member_host_flavor  = var.redis_member_host_flavor
  redis_service_endpoints   = var.redis_service_endpoints
  kms_key_crn               = module.key_protect_all_inclusive.keys["terraform-enterprise.terraform-enterprise-redis"].crn
  backup_encryption_key_crn = module.key_protect_all_inclusive.keys["terraform-enterprise.terraform-enterprise-redis-backup"].crn
  resource_tags             = var.resource_tags
  access_tags               = var.access_tags
  redis_deletion_protection = var.redis_deletion_protection
}

locals {
  redis_host               = var.existing_redis_hostname != null ? var.existing_redis_hostname : module.redis[0].redis_host
  redis_port               = var.existing_redis_port != null ? var.existing_redis_port : module.redis[0].redis_port
  redis_username           = var.existing_redis_username != null ? var.existing_redis_username : module.redis[0].redis_username
  redis_pass_base64        = var.existing_redis_password_base64 != null ? var.existing_redis_password_base64 : module.redis[0].redis_password_base64
  redis_certificate_base64 = var.existing_redis_certificate_base64 != null ? var.existing_redis_certificate_base64 : module.redis[0].redis_certificate_base64
}

########################################################################################################################
# TFE
########################################################################################################################

module "license" {
  count   = var.tfe_license_secret_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.9.0"
  crn     = var.tfe_license_secret_crn
}

# retrieving secret about the arbitrary secret
data "ibm_sm_arbitrary_secret" "tfe_license" {
  count       = var.tfe_license_secret_crn != null ? 1 : 0
  instance_id = module.license[0].service_instance
  region      = module.license[0].region
  secret_id   = module.license[0].resource
}

# retrieving the private endpoint to postgres
data "ibm_database_connection" "icd_postgres_private_connection" {
  count         = var.postgres_vpe_enabled == true && (var.postgres_service_endpoints == "public-and-private" || var.postgres_service_endpoints == "private") ? 1 : 0
  endpoint_type = "private"
  deployment_id = module.icd_postgres.id
  user_id       = module.icd_postgres.adminuser
  user_type     = "database"
}

locals {
  # concatenating secondary host with the domain configured on CIS to compute the full secondary hostname FQDN
  tfe_secondary_hostname_fqdn = var.tfe_secondary_host != null && var.existing_cis_instance_domain != null ? "${var.tfe_secondary_host}.${var.existing_cis_instance_domain}" : null

  tfe_license = var.tfe_license_secret_crn != null ? data.ibm_sm_arbitrary_secret.tfe_license[0].payload : var.tfe_license

  # if postgres_service_endpoints is "public-and-private" the icd_postgres module returns the public hostname as database hostname to use
  # but if VPE is enabled with postgres the hostname going to be used with TFE is the private one retrieved through the datasource
  icd_postgres_hostname = var.postgres_vpe_enabled == true && (var.postgres_service_endpoints == "public-and-private" || var.postgres_service_endpoints == "private") ? data.ibm_database_connection.icd_postgres_private_connection[0].postgres[0].hosts[0].hostname : module.icd_postgres.hostname
  icd_postgres_port     = var.postgres_vpe_enabled == true && (var.postgres_service_endpoints == "public-and-private" || var.postgres_service_endpoints == "private") ? data.ibm_database_connection.icd_postgres_private_connection[0].postgres[0].hosts[0].port : module.icd_postgres.port
}

module "tfe_install" {
  depends_on                     = [module.redis, module.icd_postgres_vpe]
  source                         = "./modules/tfe-install"
  cluster_id                     = module.ocp_vpc.cluster_id
  cluster_resource_group_id      = var.resource_group_id
  namespace                      = var.tfe_namespace
  tfe_license                    = local.tfe_license
  tfe_encryption_password        = var.tfe_encryption_password
  tfe_image_tag                  = var.tfe_image_tag
  tfe_image_repository           = var.tfe_image_repository
  tfe_image_pull_secret_username = var.tfe_image_pull_secret_username
  tfe_helm_chart_version         = var.tfe_helm_chart_version
  tfe_helm_repository            = var.tfe_helm_repository
  tfe_database_host              = "${local.icd_postgres_hostname}:${local.icd_postgres_port}"
  tfe_database_user              = module.icd_postgres.service_credentials_object.credentials["tfe"].username
  tfe_database_password          = module.icd_postgres.service_credentials_object.credentials["tfe"].password

  tfe_s3_bucket     = module.cos.bucket_name
  tfe_s3_region     = var.region
  tfe_s3_access_key = module.cos.resource_keys["tfe-credentials"].credentials["cos_hmac_keys.access_key_id"]
  tfe_s3_secret_key = module.cos.resource_keys["tfe-credentials"].credentials["cos_hmac_keys.secret_access_key"]
  tfe_s3_endpoint   = "https://${module.cos.s3_endpoint_direct}"

  tfe_redis_host               = local.redis_host
  tfe_redis_port               = local.redis_port
  tfe_redis_username           = local.redis_username
  tfe_redis_password           = local.redis_pass_base64
  tfe_redis_certificate_base64 = local.redis_certificate_base64

  admin_username = var.admin_username
  admin_password = var.admin_password
  admin_email    = var.admin_email

  tfe_organization   = var.tfe_organization
  tfe_extra_env_vars = var.tfe_extra_env_vars

  # tfe secondary hostname management
  tfe_secondary_hostname_fqdn        = local.tfe_secondary_hostname_fqdn
  tfe_secondary_hostname_secret_name = var.tfe_secondary_hostname_secret_name
  tfe_secondary_hostname_certificate = var.tfe_secondary_hostname_existing_secret_crn != null ? "${data.ibm_sm_public_certificate.tfe_secondary_hostname_certificate[0].certificate}${data.ibm_sm_public_certificate.tfe_secondary_hostname_certificate[0].intermediate}" : null
  tfe_secondary_hostname_key         = var.tfe_secondary_hostname_existing_secret_crn != null ? data.ibm_sm_public_certificate.tfe_secondary_hostname_certificate[0].private_key : null
}

########################################################################################################################
# Connect to Catalog Management
########################################################################################################################

resource "ibm_cm_account" "cm_account_instance" {
  count = var.add_to_catalog ? 1 : 0
  terraform_engines {
    name            = var.terraform_enterprise_engine_name
    type            = "terraform-enterprise"
    public_endpoint = module.tfe_install.tfe_console_url
    api_token       = module.tfe_install.token
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

module "existing_secrets_manager_crn" {
  count   = var.existing_secrets_manager_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.9.0"
  crn     = var.existing_secrets_manager_crn
}

module "secrets_manager_secret_group" {
  count                    = var.existing_secrets_manager_crn != null && var.existing_secrets_manager_secret_group_id == null ? 1 : 0
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.5.4"
  secret_group_name        = var.secrets_manager_secret_group_name
  secret_group_description = "Secret group for storing secrets created by the Terraform Enterprise Deployable Architecture."
  secrets_manager_guid     = module.existing_secrets_manager_crn[0].service_instance
  region                   = module.existing_secrets_manager_crn[0].region
}

locals {
  secret_group_id = var.existing_secrets_manager_crn == null ? null : var.existing_secrets_manager_secret_group_id != null ? var.existing_secrets_manager_secret_group_id : module.secrets_manager_secret_group[0].secret_group_id
}

module "redis_password_secret" {
  count                   = var.existing_secrets_manager_crn != null ? 1 : 0
  source                  = "terraform-ibm-modules/secrets-manager-secret/ibm"
  version                 = "1.10.1"
  region                  = module.existing_secrets_manager_crn[0].region
  secrets_manager_guid    = module.existing_secrets_manager_crn[0].service_instance
  secret_group_id         = local.secret_group_id
  secret_name             = var.redis_password_secret_name
  secret_description      = "Password for the Terraform Enterprise redis instance."
  secret_type             = "arbitrary"
  secret_payload_password = local.redis_pass_base64
}


########################################################################################################################
# IBM Cloud Internet Service instance management for TFE secondary hostname domain
########################################################################################################################

data "ibm_cis" "existing_cis_instance" {
  count             = var.existing_cis_instance_name != null && var.existing_cis_instance_resource_group_id != null ? 1 : 0
  name              = var.existing_cis_instance_name
  resource_group_id = var.existing_cis_instance_resource_group_id
}

data "ibm_cis_domain" "existing_cis_instance_domain" {
  count  = var.existing_cis_instance_name != null && var.existing_cis_instance_domain != null ? 1 : 0
  domain = var.existing_cis_instance_domain
  cis_id = data.ibm_cis.existing_cis_instance[0].id
}

module "tfe_dns_record" {
  count           = var.existing_cis_instance_name != null && var.existing_cis_instance_domain != null && var.create_tfe_secondary_host_on_cis ? 1 : 0
  source          = "terraform-ibm-modules/cis/ibm//modules/dns"
  version         = "2.4.1"
  cis_instance_id = data.ibm_cis.existing_cis_instance[0].id
  domain_id       = data.ibm_cis_domain.existing_cis_instance_domain[0].domain_id
  dns_record_set = [
    {
      type    = "CNAME"
      name    = "${var.tfe_secondary_host}.${var.existing_cis_instance_domain}"
      content = module.tfe_install.tfe_hostname
      ttl     = 900
    }
  ]
}

module "crn_parser_secrets_manager" {
  count   = var.tfe_secondary_hostname_existing_secret_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.9.0"
  crn     = var.tfe_secondary_hostname_existing_secret_crn
}

data "ibm_sm_public_certificate" "tfe_secondary_hostname_certificate" {
  count       = var.tfe_secondary_hostname_existing_secret_crn != null ? 1 : 0
  instance_id = module.crn_parser_secrets_manager[0].service_instance
  region      = module.crn_parser_secrets_manager[0].region
  secret_id   = module.crn_parser_secrets_manager[0].resource
}
