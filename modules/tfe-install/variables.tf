##############################################################################
# Cluster variables
##############################################################################

variable "cluster_id" {
  type        = string
  description = "The ID of the cluster you wish to deploy Terraform Enterprise to"
}

variable "cluster_resource_group_id" {
  type        = string
  description = "The Resource Group ID of the cluster"
}

variable "namespace" {
  description = "The namespace to deploy Terraform Enterprise to. This namespace will be created if it does not exist."
  type        = string
  default     = "tfe"

  validation {
    # The OCP route hostname label is built as "tfe-<namespace>.<ingress-domain>".
    # DNS labels must be ≤ 63 characters; "tfe-" consumes 4, leaving 59 for the namespace.
    condition     = length(var.namespace) <= 59
    error_message = "var.namespace must be 59 characters or fewer. The OCP route hostname is constructed as 'tfe-<namespace>.<ingress-domain>' and DNS labels must not exceed 63 characters."
  }
}

#################################################################################
# Initialize Terraform Enterprise instance variables
#################################################################################

variable "admin_username" {
  description = "The user name of the Terraform Enterprise admin user"
  type        = string
}

variable "admin_email" {
  description = "The email address of the Terraform Enterprise admin user"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.admin_email))
    error_message = "Invalid email format for admin_email. Please provide a valid email address."
  }
}

variable "admin_password" {
  description = "The password for the Terraform Enterprise admin user"
  type        = string

  validation {
    condition     = length(var.admin_password) >= 10
    error_message = "The admin password must be at least 10 characters long."
  }
  sensitive = true
}

variable "tfe_organization" {
  description = "If set, the name of the Terraform Enterprise organization to create. If not set, the module will not create an organization."
  type        = string
  default     = "default"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,63}$", var.tfe_organization))
    error_message = "The Terraform Enterprise organization name must only contain letters, numbers, underscores (_), and hyphens (-), and must not exceed 63 characters."
  }
}

##############################################################################
# Terraform Enterprise Installation variables
##############################################################################

variable "tfe_license" {
  description = "The license key for Terraform Enterprise"
  type        = string
  sensitive   = true
}

# renovate: datasource=github-releases depName=hashicorp/terraform-enterprise
variable "tfe_image_tag" {
  description = "The version tag of the Terraform Enterprise image to use. Check on https://developer.hashicorp.com/terraform/enterprise/releases for available versions."
  type        = string
  default     = "2.0.5"
}

variable "tfe_image_repository" {
  description = "The container image registry to pull the Terraform Enterprise image from. Defaults to HashiCorp's official registry ('images.releases.hashicorp.com/hashicorp/terraform-enterprise'). For IBM Passport Advantage customers, set to 'cp.icr.io/cp/hashicorp/terraform-enterprise' and provide a corresponding entitlement key as the pull secret password."
  type        = string
  default     = "images.releases.hashicorp.com/hashicorp/terraform-enterprise"
  nullable    = false
}

variable "tfe_image_pull_secret_username" {
  description = "The username used to authenticate with the image registry for the pull secret. For HashiCorp's official registry this is always 'terraform'. For IBM Cloud Container Registry (cp.icr.io) set this to 'iamapikey' and set var.tfe_license to the IBM Cloud API key that has entitlement to pull the image."
  type        = string
  default     = "terraform"
  nullable    = false
}

# renovate: datasource=helm depName=terraform-enterprise registryUrl=https://helm.releases.hashicorp.com
variable "tfe_helm_chart_version" {
  description = "The version of the Terraform Enterprise Helm chart to use. Check on https://github.com/hashicorp/terraform-enterprise-helm/blob/main/CHANGELOG.md for available versions."
  type        = string
  default     = "2.0.5"
}

variable "tfe_helm_repository" {
  description = "The Helm repository URL for Terraform Enterprise chart (e.g., 'https://helm.releases.hashicorp.com')."
  type        = string
  default     = "https://helm.releases.hashicorp.com"
  validation {
    condition     = can(regex("^https?://", var.tfe_helm_repository))
    error_message = "The Helm repository URL must start with http:// or https://"
  }
}

variable "tfe_encryption_password" {
  description = "The encryption password for Terraform Enterprise"
  type        = string
  sensitive   = true
}

variable "tfe_database_host" {
  description = "The host of the database for Terraform Enterprise, including the port - e.g. 'hostname:port'"
  type        = string
}

variable "tfe_database_user" {
  description = "The database user for Terraform Enterprise"
  type        = string
}

variable "tfe_database_password" {
  description = "The database password for Terraform Enterprise"
  type        = string
  sensitive   = true
}

variable "tfe_database_name" {
  description = "The name of the database for Terraform Enterprise"
  type        = string
  default     = "ibmclouddb"
}

variable "tfe_s3_bucket" {
  description = "The S3 bucket name for Terraform Enterprise object storage"
  type        = string
}

variable "tfe_s3_region" {
  description = "The region for the S3 bucket"
  type        = string
}

variable "tfe_s3_access_key" {
  description = "The access key for S3 object storage"
  type        = string
  sensitive   = true
}

variable "tfe_s3_secret_key" {
  description = "The secret key for S3 object storage"
  type        = string
  sensitive   = true
}

variable "tfe_s3_endpoint" {
  description = "The endpoint for S3 object storage"
  type        = string
}

variable "tfe_redis_host" {
  description = "The Redis host for Terraform Enterprise"
  type        = string
}

variable "tfe_redis_username" {
  description = "The Redis username for Terraform Enterprise"
  type        = string
  nullable    = false
  sensitive   = true
}

variable "tfe_redis_password" {
  description = "The Redis password for Terraform Enterprise"
  type        = string
  nullable    = false
  sensitive   = true
}

variable "tfe_redis_port" {
  description = "The Redis port for Terraform Enterprise"
  type        = number
  default     = 6379
}

variable "tfe_redis_certificate_base64" {
  description = "Base64 encoded TLS certificate for Redis connection (required for IBM Cloud Redis)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tfe_secondary_hostname_fqdn" {
  description = "The FQDN for the Terraform Enterprise secondary instance hostname. Default to null."
  type        = string
  default     = null
  validation {
    condition     = var.tfe_secondary_hostname_fqdn == null || (var.tfe_secondary_hostname_fqdn != null && var.tfe_secondary_hostname_certificate != null && var.tfe_secondary_hostname_key != null)
    error_message = "If var.tfe_secondary_hostname_fqdn the inputs parameters var.tfe_secondary_hostname_certificate and var.tfe_secondary_hostname_key cannot be null."
  }
}

variable "tfe_secondary_hostname_certificate" {
  description = "The TLS certificate for the Terraform Enterprise instance secondary hostname. It is required to configure the Terraform Enterprise secondary hostname. Default to null."
  type        = string
  default     = null
}

variable "tfe_secondary_hostname_key" {
  description = "The TLS certificate private key for the Terraform Enterprise instance secondary hostname. It is required to configure a Terraform Enterprise secondary hostname. Default to null."
  type        = string
  default     = null
}

variable "tfe_secondary_hostname_secret_name" {
  description = "The secret name to be used to store the TLS certificate on the OCP cluster for the Terraform Enterprise instance secondary hostname. Default to 'terraform-enterprise-certificates-secondary'."
  type        = string
  default     = "terraform-enterprise-certificates-secondary"
}


variable "tfe_service_servicetype" {
  description = "TFE primary service ServiceType configuration. Allowed values are ClusterIP and LoadBalancer. Default to ClusterIP."
  type        = string
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "LoadBalancer"], var.tfe_service_servicetype)
    error_message = "The value of var.tfe_service_servicetype cannot be different from ClusterIP or LoadBalancer"
  }
}

variable "tfe_service_secondary_servicetype" {
  description = "TFE secondary service ServiceType configuration. Allowed values are ClusterIP and LoadBalancer. Default to ClusterIP."
  type        = string
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "LoadBalancer"], var.tfe_service_secondary_servicetype)
    error_message = "The value of var.tfe_service_secondary_servicetype cannot be different from ClusterIP or LoadBalancer"
  }
}

variable "tfe_pod_template_security_config" {
  description = "Security configuration of the deployment of TFE to put into the TFE_RUN_PIPELINE_KUBERNETES_POD_TEMPLATE TFE environment variable"
  type        = string
  default     = "{\"securityContext\":{\"allowPrivilegeEscalation\":false,\"capabilities\":{\"drop\":[\"ALL\"]},\"runAsNonRoot\":true,\"seccompProfile\":{\"type\":\"RuntimeDefault\"}}}"
}

variable "tfe_service_admin_node_port" {
  description = "Admin NodePort for the TFE primary service. Null doesn't expose the port on the service. Default to null"
  type        = string
  default     = null
}

variable "tfe_service_secondary_admin_node_port" {
  description = "Admin NodePort for the TFE primary service. Null doesn't expose the port on the service. Default to null."
  type        = string
  default     = null
}

variable "tfe_deployment_replicas" {
  description = "TFE deployment replicas. Default to 3."
  type        = number
  default     = 3
}

variable "tfe_resources_configuration_memory" {
  description = "TFE deployment resource configuration for the memory. Default to 3000Mi."
  type        = string
  default     = "3000Mi"
}

variable "tfe_resources_configuration_cpu" {
  description = "TFE deployment resource configuration for the CPU. Default to 1."
  type        = string
  default     = "1"
}

variable "tfe_extra_env_vars" {
  description = "Additional environment variables to pass to the Terraform Enterprise deployment as plain (non-sensitive) values. Keys must be valid Terraform Enterprise configuration variable names (e.g. 'TFE_CAPACITY_CONCURRENCY'). See https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration for the full list. These are merged with the module-managed variables and can override defaults."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "rollback_on_failure" {
  description = "Flag to automatically rollback the helm chart on installation failure."
  type        = bool
  default     = true
}

variable "pg_extension_job_image" {
  description = "Container image used by the TFE init container that creates required PostgreSQL extensions in IBM Cloud before TFE starts. The image must contain the 'psql' binary. Override this in air-gapped or private-registry environments. See https://hub.docker.com/_/postgres for available tags."
  type        = string
  default     = "postgres:16-alpine"
  nullable    = false
}

variable "tfe_startup_checks_ignore_failures" {
  description = "Comma-separated list of startup checks to treat as warnings instead of blocking startup. Useful for tolerating expired certificates in CA bundles. Example: 'tls'. Default is null (all checks must pass)."
  type        = string
  default     = null
}
