########################################################################################################################
# Input Variables
########################################################################################################################

variable "resource_group_id" {
  type        = string
  description = "The Resource Group ID to use for all resources created in this solution (VPC and cluster)"
  default     = null
}

variable "region" {
  type        = string
  description = "Region where resources are created"
  default     = "eu-es"
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the resources created by the module"
  default     = []
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

variable "existing_vpc_id" {
  type        = string
  description = "The ID of the existing vpc. If not set, a new VPC will be created."
  default     = null
}

variable "existing_cluster_id" {
  type        = string
  description = "The CRN of the existing cluster. If not set, a new cluster will be created."
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

variable "kms_config" {
  type = object({
    crk             = string
    kms_instance_id = string
    kms_account_id  = optional(string) # To attach KMS instance from another account
  })
  description = "Use to attach a KMS instance to the cluster. If kms_account_id is not provided, defaults to the account in use."
  default     = null
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

variable "workers_per_zone" {
  type        = number
  description = "Number of worker nodes to provision per zone in the default worker pool. Increase this value for higher availability or heavier workloads. Default is 2."
  default     = 2
  nullable    = false
}

variable "worker_node_flavor" {
  type        = string
  description = "The VPC machine type (flavor) for worker nodes in the default pool (e.g. 'bx2.4x16', 'bx2.8x32', 'bx2.16x64'). See https://cloud.ibm.com/docs/vpc?topic=vpc-profiles for available profiles. Default is 'bx2.4x16' (4 vCPU, 16 GB RAM)."
  default     = "bx2.4x16"
  nullable    = false
}
