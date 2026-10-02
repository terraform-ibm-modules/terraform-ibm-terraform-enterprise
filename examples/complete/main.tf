locals {
  prefix = var.prefix != null ? trimspace(var.prefix) != "" ? "${var.prefix}-" : "" : ""
}

########################################################################################################################
# Loading existing resource group
########################################################################################################################


locals {
  # these ACLs would enable traffic to/from the ICD postgres instance only from/to the VPE punctual IPs
  # as these ACLs are depending on VCP creation must be attached to the VPC after both VPC and VPE are created
  # leaving these here for documentation reference purposes
  # vpe punctual IPs for ACL rules
  # tflint-ignore: terraform_unused_declarations
  # postgres_vpe_acl_rules_strict = flatten([
  #   for subnet, cidr in var.subnets_zones_cidr : [
  #     for vpe in module.tfe.icd_postgres_vpe[0].vpe_ips : concat([
  #       for vpe_ip_name, vpe_ip in vpe : {
  #         name        = "allow-postgres-inbound-from-vpe-${vpe_ip_name}"
  #         action      = "allow"
  #         direction   = "inbound"
  #         source      = vpe_ip.address
  #         destination = cidr
  #         tcp = {
  #           source_port_max = module.tfe.icd_postgres_port
  #           source_port_min = module.tfe.icd_postgres_port
  #         }
  #       }
  #       ],
  #       [
  #         for vpe_ip_name, vpe_ip in vpe : {
  #           name        = "allow-postgres-outbound-to-vpe-${vpe_ip_name}"
  #           action      = "allow"
  #           direction   = "outbound"
  #           destination = vpe_ip.address
  #           source      = cidr
  #           tcp = {
  #             source_port_max = module.tfe.icd_postgres_port
  #             source_port_min = module.tfe.icd_postgres_port
  #           }
  #         }
  #       ]
  #     )
  #   ]
  # ])
}

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.6.1"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.existing_resource_group_name == null ? "${local.prefix}resource-group" : null
  existing_resource_group_name = var.existing_resource_group_name
}

module "tfe" {
  source                                   = "../.."
  region                                   = var.region
  resource_group_id                        = module.resource_group.resource_group_id
  resource_tags                            = var.resource_tags
  vpc_name                                 = "${local.prefix}vpc"
  cluster_name                             = "${local.prefix}cluster"
  postgres_instance_name                   = "${local.prefix}data-store"
  cos_instance_name                        = "${local.prefix}cos"
  cos_bucket_name                          = "${local.prefix}cos-bucket"
  tfe_license                              = var.tfe_license
  tfe_encryption_password                  = var.tfe_encryption_password
  tfe_image_tag                            = var.tfe_image_tag
  tfe_image_repository                     = var.tfe_image_repository
  tfe_image_pull_secret_username           = var.tfe_image_pull_secret_username
  tfe_helm_chart_version                   = var.tfe_helm_chart_version
  tfe_helm_repository                      = var.tfe_helm_repository
  tfe_license_secret_crn                   = var.tfe_license_secret_crn
  admin_username                           = var.admin_username
  admin_password                           = var.admin_password
  admin_email                              = var.admin_email
  tfe_organization                         = var.tfe_organization_name
  postgres_deletion_protection             = var.postgres_deletion_protection
  postgres_vpe_enabled                     = var.postgres_vpe_enabled
  postgres_service_endpoints               = var.postgres_service_endpoints
  postgres_vpe_service_endpoints           = var.postgres_vpe_service_endpoints
  subnets_zones_cidr                       = var.subnets_zones_cidr
  vpc_acl_rules                            = var.vpc_acl_rules
  postgres_add_acl_rule                    = var.postgres_add_acl_rule
  kms_key_deletion_protection              = var.kms_key_deletion_protection
  redis_deletion_protection                = var.redis_deletion_protection
  add_to_catalog                           = var.add_to_catalog
  existing_secrets_manager_crn             = var.secrets_manager_crn
  existing_secrets_manager_secret_group_id = var.secrets_manager_secret_group_id
  redis_password_secret_name               = "${local.prefix}redis-password"
  secrets_manager_secret_group_name        = "${local.prefix}secrets-group"
  # TFE secondary hostname management
  tfe_secondary_host                         = var.tfe_secondary_host
  existing_cis_instance_name                 = var.existing_cis_instance_name
  existing_cis_instance_resource_group_id    = var.existing_cis_instance_resource_group_id
  existing_cis_instance_domain               = var.existing_cis_instance_domain
  create_tfe_secondary_host_on_cis           = var.create_tfe_secondary_host_on_cis
  tfe_secondary_hostname_existing_secret_crn = var.tfe_secondary_hostname_existing_secret_crn
  tfe_secondary_hostname_secret_name         = var.tfe_secondary_hostname_secret_name
}
