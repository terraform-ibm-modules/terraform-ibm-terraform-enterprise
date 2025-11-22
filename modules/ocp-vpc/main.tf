########################################################################################################################
# VPC
########################################################################################################################

module "vpc" {
  source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version           = "8.9.1"
  resource_group_id = var.resource_group_id
  region            = var.region
  create_vpc        = var.existing_vpc_id == null ? true : false
  existing_vpc_id   = var.existing_vpc_id
  prefix            = var.prefix
  name              = "${var.prefix}-vpc"
  tags              = []
  address_prefixes = {
    zone-1 = ["10.10.10.0/24"]
    zone-2 = ["10.20.10.0/24"]
  }
  clean_default_sg_acl = true
  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules = [
        {
          name        = "allow-all-inbound"
          action      = "allow"
          direction   = "inbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
        },
        {
          name        = "allow-all-outbound"
          action      = "allow"
          direction   = "outbound"
          source      = "0.0.0.0/0"
          destination = "0.0.0.0/0"
        }
      ]
    }
  ]
  enable_vpc_flow_logs                   = false
  create_authorization_policy_vpc_to_cos = false
  #existing_storage_bucket_name           = module.flowlogs_bucket.bucket_configs[0].bucket_name
  security_group_rules = []
  #existing_cos_instance_guid             = module.cos_fscloud.cos_instance_guid
  subnets = {
    zone-1 = [
      {
        acl_name       = "vpc-acl"
        name           = "zone-1"
        cidr           = "10.10.10.0/24"
        public_gateway = true
      }
    ],
    zone-2 = [
      {
        acl_name       = "vpc-acl"
        name           = "zone-2"
        cidr           = "10.20.10.0/24"
        public_gateway = true
      }
    ]
  }
  use_public_gateways = {
    zone-1 = true
    zone-2 = true
    zone-3 = false
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
      subnet_prefix     = "default"
      pool_name         = "default"  # ibm_container_vpc_cluster automatically names default pool "default" (See https://github.com/IBM-Cloud/terraform-provider-ibm/issues/2849)
      machine_type      = "bx2.4x16" # smallest machine type available in VPC
      workers_per_zone  = 2
      operating_system  = "RHCOS"
      labels            = {}
      resource_group_id = var.resource_group_id
    }
  ]
}

module "openshift" {
  count                               = var.existing_cluster_id == null ? 1 : 0
  source                              = "terraform-ibm-modules/base-ocp-vpc/ibm"
  version                             = "3.73.2"
  cluster_name                        = var.prefix
  resource_group_id                   = var.resource_group_id
  region                              = var.region
  force_delete_storage                = true
  vpc_id                              = module.vpc.vpc_id
  vpc_subnets                         = local.cluster_vpc_subnets
  worker_pools                        = local.worker_pools
  tags                                = var.resource_tags
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
}
