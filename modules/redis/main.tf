##############################################################################
# IBM Cloud Database for Redis
##############################################################################

module "icd_redis" {
  source             = "terraform-ibm-modules/icd-redis/ibm"
  version            = "2.14.2"
  resource_group_id  = var.resource_group_id
  name               = var.redis_instance_name
  region             = var.region
  redis_version      = var.redis_version
  member_host_flavor = var.redis_member_host_flavor
  service_endpoints  = var.redis_service_endpoints

  # KMS encryption
  use_ibm_owned_encryption_key = false
  kms_key_crn                  = var.kms_key_crn
  use_same_kms_key_for_backups = false
  backup_encryption_key_crn    = var.backup_encryption_key_crn

  # Service credentials — always use private endpoint for the credential connection string
  service_credential_names = [
    {
      name     = "tfe"
      role     = "Administrator"
      endpoint = "private"
    }
  ]

  # Resource tags
  tags        = var.resource_tags
  access_tags = var.access_tags

  # Deletion protection
  deletion_protection = var.redis_deletion_protection
}
