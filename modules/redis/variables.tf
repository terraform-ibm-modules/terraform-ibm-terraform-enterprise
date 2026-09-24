##############################################################################
# Redis variables
##############################################################################

variable "resource_group_id" {
  type        = string
  description = "The ID of the resource group to use for the Redis instance"
}

variable "redis_instance_name" {
  type        = string
  description = "Name of the Redis instance to create"
}

variable "region" {
  type        = string
  description = "Region where the Redis instance will be created"
}

variable "redis_version" {
  type        = string
  description = "Version of Redis to provision. Defaults to '8.2', which is the version tested with Terraform Enterprise. Must be in 'x.y' format (e.g. '7.2', '8.2'). Set to null to use the IBM Cloud preferred default."
  default     = "8.2"
}

variable "redis_member_host_flavor" {
  type        = string
  description = "Host flavor for Redis members"
  default     = "multitenant"
}

variable "redis_service_endpoints" {
  type        = string
  description = "Service endpoints for the Redis instance. Default is private."
  default     = "private"
  validation {
    condition     = contains(["private", "public-and-private"], var.redis_service_endpoints)
    error_message = "Allowed values for var.redis_service_endpoints are 'private' and 'public-and-private'"
  }
}

variable "kms_key_crn" {
  type        = string
  description = "The CRN of the KMS key to use for encrypting the Redis instance"
}

variable "backup_encryption_key_crn" {
  type        = string
  description = "The CRN of the KMS key to use for encrypting Redis backups"
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to the Redis instance"
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "Optional list of access tags to be added to the Redis instance"
  default     = []
}

variable "redis_deletion_protection" {
  type        = bool
  description = "Enable deletion protection for the Redis instance"
  default     = true
}
