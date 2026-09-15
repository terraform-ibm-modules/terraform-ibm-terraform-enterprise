########################################################################################################################
# VPC
########################################################################################################################

module "vpc" {
  source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version           = "9.1.2"
  resource_group_id = var.resource_group_id
  region            = var.region
  create_vpc        = var.existing_vpc_id == null ? true : false
  existing_vpc_id   = var.existing_vpc_id
  name              = var.vpc_name
  resource_tags     = []
  address_prefixes = {
    for zone, cidr in var.subnets_zones_cidr :
    zone => [cidr]
  }
  clean_default_sg_acl = true
  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules                        = var.vpc_acl_rules
    }
  ]
  enable_vpc_flow_logs                   = false
  create_authorization_policy_vpc_to_cos = false
  #existing_storage_bucket_name           = module.flowlogs_bucket.bucket_configs[0].bucket_name
  security_group_rules = []
  #existing_cos_instance_guid             = module.cos_fscloud.cos_instance_guid
  subnets = {
    for zone, cidr in var.subnets_zones_cidr :
    zone => [
      {
        acl_name       = "vpc-acl"
        name           = zone
        cidr           = cidr
        public_gateway = true
      }
    ]
  }
  use_public_gateways = {
    for zone, cidr in var.subnets_zones_cidr :
    zone => true
  }
}

########################################################################################################################
# OCP VPC Cluster
########################################################################################################################

locals {
  cluster_vpc_subnets = {
    default = [
      for subnet in module.vpc.subnet_zone_list :
      {
        id         = subnet.id
        zone       = subnet.zone
        cidr_block = subnet.cidr
      }
    ]
  }

  worker_pools = [
    {
      subnet_prefix                     = "default"
      pool_name                         = "default"  # ibm_container_vpc_cluster automatically names default pool "default" (See https://github.com/IBM-Cloud/terraform-provider-ibm/issues/2849)
      machine_type                      = "bx2.4x16" # smallest machine type available in VPC
      workers_per_zone                  = 2
      operating_system                  = "RHCOS"
      labels                            = {}
      resource_group_id                 = var.resource_group_id
      boot_volume_encryption_kms_config = var.kms_config
    }
  ]
}

module "openshift" {
  count                               = var.existing_cluster_id == null ? 1 : 0
  source                              = "terraform-ibm-modules/base-ocp-vpc/ibm"
  version                             = "3.90.3"
  cluster_name                        = var.cluster_name
  resource_group_id                   = var.resource_group_id
  region                              = var.region
  force_delete_storage                = true
  vpc_id                              = module.vpc.vpc_id
  vpc_subnets                         = local.cluster_vpc_subnets
  worker_pools                        = local.worker_pools
  resource_tags                       = var.resource_tags
  access_tags                         = var.access_tags
  ocp_version                         = var.ocp_version
  ocp_entitlement                     = var.ocp_entitlement
  enable_ocp_console                  = true
  disable_outbound_traffic_protection = true
}

data "ibm_container_vpc_cluster" "cluster" {
  count             = var.existing_cluster_id != null ? 1 : 0
  name              = var.existing_cluster_id
  resource_group_id = var.resource_group_id
}

locals {
  cluster_name     = var.existing_cluster_id != null ? data.ibm_container_vpc_cluster.cluster[0].name : module.openshift[0].cluster_name
  cluster_id       = var.existing_cluster_id != null ? data.ibm_container_vpc_cluster.cluster[0].id : module.openshift[0].cluster_id
  ingress_hostname = var.existing_cluster_id != null ? data.ibm_container_vpc_cluster.cluster[0].ingress_hostname : module.openshift[0].ingress_hostname
  vpc_id           = module.vpc.vpc_id
  vpc_name         = module.vpc.vpc_name
}

locals {
  cluster_security_group = [for group in data.ibm_is_security_groups.vpc_security_groups.security_groups : group if group.name == "kube-${local.cluster_id}"][0]
}

data "ibm_is_security_groups" "vpc_security_groups" {
  vpc_id = var.existing_cluster_id != null ? module.vpc.id : module.openshift[0].vpc_id
  depends_on = [module.openshift]
}

# Kube-<vpc id> Security Group
data "ibm_is_security_group" "kube_cluster_sg" {
  name = local.cluster_security_group.name
}

data "ibm_is_vpc" "vpc" {
  identifier = local.vpc_id
}
