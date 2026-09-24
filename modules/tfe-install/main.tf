data "ibm_container_vpc_cluster" "cluster" {
  name              = var.cluster_id
  resource_group_id = var.cluster_resource_group_id
}

resource "kubernetes_namespace_v1" "tfe" {
  metadata {
    name = var.namespace
  }

  # Ignore annotations that TFE may add to namespace
  lifecycle {
    ignore_changes = [
      metadata["annotations"],
    ]
  }
}

locals {
  # Extract the registry hostname (everything before the first "/") from the
  # image repository so the pull secret targets the correct registry.
  # e.g. "images.releases.hashicorp.com/hashicorp/terraform-enterprise" → "images.releases.hashicorp.com"
  # e.g. "cp.icr.io/cp/hashicorp/terraform-enterprise"                  → "cp.icr.io"
  tfe_registry_hostname = split("/", var.tfe_image_repository)[0]
}

resource "kubernetes_secret_v1" "tfe_pull_secret" {
  # This secret is used to pull the Terraform Enterprise image from the registry.
  # For HashiCorp's registry the username is always "terraform" and the password is the TFE license.
  # For IBM ICR (cp.icr.io) the username is "iamapikey" and the password is an IBM Cloud API key;
  # set var.tfe_image_pull_secret_username accordingly when switching registries.
  metadata {
    name      = "terraform-enterprise"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (local.tfe_registry_hostname) = {
          "username" = var.tfe_image_pull_secret_username
          "password" = var.tfe_license
          "auth"     = base64encode("${var.tfe_image_pull_secret_username}:${var.tfe_license}")
        }
      }
    })
  }
}

locals {
  tfe_deployment_replicas = var.tfe_deployment_replicas != null ? var.tfe_deployment_replicas : 3
  route_name              = "tfe"
  tfe_hostname            = "${local.route_name}-${var.namespace}.${data.ibm_container_vpc_cluster.cluster.ingress_hostname}" # Compute the TFE hostname based on the namespace and cluster ingress hostname. Not putting a dependency on the route resource here, as it is created after the helm release.

  # building the list of values to configure in the helm release
  set_values_list = [
    {
      name  = "image.repository"
      value = var.tfe_image_repository
    },
    {
      name  = "image.tag"
      value = var.tfe_image_tag
    },
    {
      name  = "openshift.enabled"
      value = true
    },
    {
      name  = "env.variables.TFE_HOSTNAME"
      value = local.tfe_hostname
    },
    {
      name  = "env.variables.TFE_TLS_CERT_FILE"
      value = "/etc/ssl/private/terraform-enterprise/tls.crt"
    },
    {
      name  = "env.variables.TFE_TLS_KEY_FILE"
      value = "/etc/ssl/private/terraform-enterprise/tls.key"
    },
    {
      name  = "env.variables.TFE_LICENSE_REPORTING_OPT_OUT"
      value = true
    },
    {
      name  = "env.variables.TFE_USAGE_REPORTING_OPT_OUT"
      value = true
    },
    {
      name  = "env.variables.TFE_INSTALLATION_TYPE"
      value = "openshift"
    },
    {
      name  = "env.variables.TFE_DATABASE_HOST"
      value = var.tfe_database_host
    },
    {
      name  = "env.variables.TFE_DATABASE_PARAMETERS"
      value = "sslmode=require"
    },
    {
      name  = "env.variables.TFE_DATABASE_EXTENSION_SCHEMA"
      value = "ibm_extension"
    },
    {
      name  = "env.variables.TFE_DATABASE_EXTRA_SCHEMAS"
      value = "ibm_extension"
    },
    {
      name  = "env.variables.TFE_DATABASE_USER"
      value = var.tfe_database_user
    },
    {
      name  = "env.variables.TFE_DATABASE_NAME"
      value = var.tfe_database_name
    },
    {
      name  = "env.variables.TFE_RUN_PIPELINE_DRIVER"
      value = "kubernetes"
    },
    {
      name  = "env.variables.TFE_VAULT_DISABLE_MLOCK"
      value = true
    },
    {
      name  = "env.variables.TFE_RUN_PIPELINE_KUBERNETES_OPEN_SHIFT_ENABLED"
      value = true
    },
    {
      name  = "env.variables.TFE_HTTP_PORT"
      value = "8080"
    },
    {
      name  = "env.variables.TFE_REDIS_USE_AUTH"
      value = true
    },
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_S3_BUCKET"
      value = var.tfe_s3_bucket
    },
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_TYPE"
      value = "s3"
    },
    {
      name  = "env.variables.TFE_REDIS_USE_TLS"
      value = true
    },
    {
      name  = "env.variables.TFE_REDIS_HOST"
      value = "${var.tfe_redis_host}:${var.tfe_redis_port}"
    },
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_S3_REGION"
      value = var.tfe_s3_region
    },
    {
      name  = "env.variables.TFE_OPERATIONAL_MODE"
      value = "external"
    },
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_S3_ENDPOINT"
      value = var.tfe_s3_endpoint
    },
    {
      name  = "env.variables.TFE_RUN_PIPELINE_IMAGE"
      value = data.kubernetes_resource.tfe_agent_image_stream.object.status.dockerImageRepository
    },
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_S3_USE_INSTANCE_PROFILE"
      value = false
    },
    {
      name  = "env.variables.TFE_RUN_PIPELINE_KUBERNETES_NAMESPACE"
      value = kubernetes_namespace_v1.tfe.metadata[0].name
    },
    {
      name  = "agents.namespace.enabled"
      value = false
    },
    {
      name  = "agents.namespace.name"
      value = kubernetes_namespace_v1.tfe.metadata[0].name
    },
    {
      name  = "serviceAccount.create"
      value = false
    },
    {
      name  = "serviceAccount.name"
      value = "tfe"
    },
    {
      name  = "replicaCount"
      value = local.tfe_deployment_replicas
    },
    {
      name  = "tfe.readinessProbePath"
      value = "/api/v1/health/readiness"
    }
  ]

  # Conditionally add TFE_STARTUP_CHECKS_IGNORE_FAILURES if specified
  set_values_list_startup_checks = var.tfe_startup_checks_ignore_failures != null ? [
    {
      name  = "env.variables.TFE_STARTUP_CHECKS_IGNORE_FAILURES"
      value = var.tfe_startup_checks_ignore_failures
    }
  ] : []

  # adding values to helm release if a secondary TFE hostname is to be configured
  set_values_list_secondary_hostname = var.tfe_secondary_hostname_fqdn != null ? [
    {
      name  = "env.variables.TFE_HOSTNAME_SECONDARY"
      value = var.tfe_secondary_hostname_fqdn
    },
    {
      name  = "env.variables.TFE_TLS_KEY_FILE_SECONDARY"
      value = "/etc/ssl/private/terraform-enterprise/ext_key.pem"
    },
    {
      name  = "env.variables.TFE_TLS_CERT_FILE_SECONDARY"
      value = "/etc/ssl/private/terraform-enterprise/ext_cert.pem"
    },
    {
      name  = "tlsSecondary.certMountPath"
      value = "/etc/ssl/private/terraform-enterprise/ext_cert.pem"
    },
    {
      name  = "tlsSecondary.keyMountPath"
      value = "/etc/ssl/private/terraform-enterprise/ext_key.pem"
    },
    {
      name  = "tlsSecondary.certificateSecret"
      value = var.tfe_secondary_hostname_secret_name
    }
    ] : [
    {
      name  = "tlsSecondary.certData"
      value = ""
    },
    {
      name  = "tlsSecondary.keyData"
      value = ""
    }
  ]

  # concatenating values for the final list
  set_values_list_final = concat(
    local.set_values_list,
    local.set_values_list_secondary_hostname,
    local.set_values_list_startup_checks
  )

  # Extract environment variables from set_values_list for the values block,
  # then merge any caller-supplied extra env vars (var.tfe_extra_env_vars).
  # Extra vars are applied last so they can override or extend the defaults.
  env_variables = merge(
    {
      for item in local.set_values_list_final :
      replace(item.name, "env.variables.", "") => item.value
      if startswith(item.name, "env.variables.") && item.name != "env.variables.TFE_REDIS_PORT"
    },
    var.tfe_extra_env_vars
  )

  # building the list of sensitive values
  set_sensitive_values_list = [
    {
      name  = "env.secrets.TFE_LICENSE"
      value = var.tfe_license
    },
    {
      name  = "env.secrets.TFE_ENCRYPTION_PASSWORD"
      value = var.tfe_encryption_password
    },
    {
      name  = "env.secrets.TFE_OBJECT_STORAGE_S3_SECRET_ACCESS_KEY"
      value = var.tfe_s3_secret_key
    },
    {
      name  = "env.secrets.TFE_DATABASE_PASSWORD"
      value = var.tfe_database_password
    },
    {
      name  = "env.secrets.TFE_REDIS_USER"
      value = var.tfe_redis_username
    },
    {
      name  = "env.secrets.TFE_REDIS_PASSWORD"
      value = base64decode(var.tfe_redis_password)
    },
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_S3_ACCESS_KEY_ID"
      value = var.tfe_s3_access_key
    },
    {
      name  = "env.variables.TFE_RUN_PIPELINE_KUBERNETES_POD_TEMPLATE"
      value = base64encode(var.tfe_pod_template_security_config)
    },
    {
      name  = "env.secrets.TFE_IACT_TOKEN"
      value = random_string.iact_token.result
    },
  ]

  # building the list of sensitive values if a secondary TFE hostname is to be configured
  set_sensitive_values_list_secondary_hostname = var.tfe_secondary_hostname_certificate != null && var.tfe_secondary_hostname_key != null ? [
    {
      name  = "tlsSecondary.certData"
      value = base64encode(var.tfe_secondary_hostname_certificate)
    },
    {
      name  = "tlsSecondary.keyData"
      value = base64encode(var.tfe_secondary_hostname_key)
  }] : []

  # concatenating sensitive values for the final list
  set_sensitive_values_list_final = concat(local.set_sensitive_values_list, local.set_sensitive_values_list_secondary_hostname)
}

locals {
  tfe_deployment_labels      = {}
  tfe_deployment_annotations = {}

  tfe_deployment_values = {
    "labels"      = local.tfe_deployment_labels
    "annotations" = local.tfe_deployment_annotations
  }

  tfe_service_values = {
    "annotations" : {
      "service.beta.openshift.io/serving-cert-secret-name" : "terraform-enterprise-certificates",
    },
    "labels" : {},
    "type" : var.tfe_service_servicetype,
    "adminNodePort" : var.tfe_service_admin_node_port,
  }

  tfe_service_account = {}

  tfe_secret = {}

  tfe_agents_rbac = {}

  tfe_secondary_hostname_secret_name = var.tfe_secondary_hostname_secret_name != null && var.tfe_secondary_hostname_secret_name != "" ? var.tfe_secondary_hostname_secret_name : "terraform-enterprise-certificates-secondary"

  tfe_service_secondary_values = var.tfe_secondary_hostname_fqdn != null ? {
    "annotations" : {
      "service.beta.openshift.io/serving-cert-secret-name" : "${local.tfe_secondary_hostname_secret_name}-internal",
    },
    "labels" : {},
    "type" : var.tfe_service_secondary_servicetype,
    "adminNodePort" : var.tfe_service_secondary_admin_node_port,
  } : null

  tfe_resources_configuration = {
    "requests" : {
      "memory" : var.tfe_resources_configuration_memory != null && var.tfe_resources_configuration_memory != "" ? var.tfe_resources_configuration_memory : "3000Mi",
      "cpu" : var.tfe_resources_configuration_cpu != null && var.tfe_resources_configuration_cpu != "" ? var.tfe_resources_configuration_cpu : "1",
    }
  }
}

# ########################################################################################################################
# # Terraform Enterprise Helm Chart
# ########################################################################################################################

resource "helm_release" "tfe_install" {
  depends_on = [
    kubernetes_secret_v1.tfe_pull_secret,
    kubernetes_namespace_v1.tfe,
  ]

  name             = "terraform-enterprise"
  repository       = var.tfe_helm_repository
  chart            = "terraform-enterprise"
  version          = var.tfe_helm_chart_version
  namespace        = kubernetes_namespace_v1.tfe.metadata[0].name
  create_namespace = false
  timeout          = 1200 # 20 minutes timeout for TFE deployment
  wait             = true # Wait for pods to reach ready state; surfaces deployment errors clearly
  wait_for_jobs    = true # Wait for any Helm-managed jobs to complete
  recreate_pods    = true
  force_update     = true
  reset_values     = true
  atomic           = var.rollback_on_failure

  set = [
    for item in local.set_values_list_final : {
      name  = item.name
      value = tostring(item.value)
    }
  ]

  set_sensitive = [
    for item in local.set_sensitive_values_list_final : {
      name  = item.name
      value = item.value
    }
  ]

  values = [
    yamlencode({
      "config" = {
        "annotations" = {}
      }
      "env" = {
        "variables" = local.env_variables
      }
      "agents" = {
        "namespace" = {
          "enabled" = false
        },
        "rbac" = local.tfe_agents_rbac
      }
      "deployment" = local.tfe_deployment_values,
      # IBM Cloud Redis uses one-way TLS — only a CA cert is needed to verify the
      # server. Setting tls.caCertData adds the cert to TFE's global CA bundle
      # (TFE_TLS_CA_BUNDLE_FILE) so it trusts the Redis server certificate.
      # The tlsRedis mTLS block (certData+keyData+caCertData) is not used because
      # IBM Cloud Redis does not require mutual TLS.
      "tls" = {
        "caCertData" = var.tfe_redis_certificate_base64 != "" ? var.tfe_redis_certificate_base64 : null
      },
      "tlsRedis" = {
        "certData" = ""
        "keyData"  = ""
      },
      "tlsRedisSidekiq" = {
        "certData" = ""
        "keyData"  = ""
      },
      "initContainers" = [
        {
          "name"  = "pg-extensions"
          "image" = var.pg_extension_job_image
          "command" = [
            "sh", "-c",
            join("\n", [
              "until psql \"$DATABASE_URL\" -c '\\q' 2>/dev/null; do echo 'Waiting for database...'; sleep 2; done",
              "psql \"$DATABASE_URL\" <<-EOSQL",
              "  CREATE SCHEMA IF NOT EXISTS ibm_extension;",
              "  CREATE EXTENSION IF NOT EXISTS hstore    WITH SCHEMA ibm_extension;",
              "  CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\" WITH SCHEMA ibm_extension;",
              "  CREATE EXTENSION IF NOT EXISTS citext    WITH SCHEMA ibm_extension;",
              "EOSQL",
              "echo 'PostgreSQL extensions ready.'",
            ])
          ]
          "env" = [
            {
              "name"  = "DATABASE_URL"
              "value" = "postgresql://${var.tfe_database_user}:${var.tfe_database_password}@${var.tfe_database_host}/${var.tfe_database_name}?sslmode=require"
            }
          ]
        }
      ],
      "container" = {
        "securityContext" = {
          "runAsUser" = 1000
        }
      },
      "service"          = local.tfe_service_values,
      "serviceSecondary" = local.tfe_service_secondary_values,
      "serviceAccount"   = local.tfe_service_account,
      "resources"        = local.tfe_resources_configuration,
      "secret"           = local.tfe_secret,
    }),
  ]
}

resource "random_string" "iact_token" {
  length  = 10
  special = false
}

resource "kubernetes_role_binding_v1" "tfe_admin" {
  metadata {
    name      = "tfe-anyuuid"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:openshift:scc:anyuid"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "tfe"
    namespace = var.namespace
  }
}

# The OCP router's external LB IP is unreachable from within the cluster (hairpin).
# Inject a hostAliases entry pointing the TFE hostname to the internal router
# ClusterIP so that TFE agents can reach the TFE API without leaving the cluster.
data "kubernetes_service_v1" "router_internal" {
  metadata {
    name      = "router-internal-default"
    namespace = "openshift-ingress"
  }
}

resource "kubectl_manifest" "tfe_host_alias_patch" {
  depends_on        = [helm_release.tfe_install]
  yaml_body         = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: terraform-enterprise
      namespace: ${kubernetes_namespace_v1.tfe.metadata[0].name}
    spec:
      template:
        spec:
          hostAliases:
            - ip: "${data.kubernetes_service_v1.router_internal.spec[0].cluster_ip}"
              hostnames:
                - "${local.tfe_hostname}"
  YAML
  force_conflicts   = true
  server_side_apply = true
}

resource "kubectl_manifest" "tfe_route" {
  depends_on = [helm_release.tfe_install]

  yaml_body = <<-YAML
    apiVersion: route.openshift.io/v1
    kind: Route
    metadata:
      name: ${local.route_name}
      namespace: ${kubernetes_namespace_v1.tfe.metadata[0].name}
    spec:
      to:
        kind: Service
        name: terraform-enterprise
      port:
        targetPort: https-port
      tls:
        termination: reencrypt
        insecureEdgeTerminationPolicy: None
  YAML
}

resource "kubectl_manifest" "tfe_secondary_route" {
  depends_on = [helm_release.tfe_install]
  count      = var.tfe_secondary_hostname_fqdn != null ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: route.openshift.io/v1
    kind: Route
    metadata:
      name: "tfe-secondary-route"
      namespace: ${kubernetes_namespace_v1.tfe.metadata[0].name}
    spec:
      host: ${var.tfe_secondary_hostname_fqdn}
      to:
        kind: Service
        name: terraform-enterprise
      port:
        targetPort: https-port
      tls:
        termination: passthrough
        insecureEdgeTerminationPolicy: None
  YAML

}

# Admin user creation via external script after Helm install completes
data "external" "admin_user_token" {
  depends_on = [helm_release.tfe_install]
  program = [
    "${path.module}/scripts/create_admin_user.sh",
    local.tfe_hostname,
    random_string.iact_token.result,
    var.admin_username,
    var.admin_email,
    var.admin_password
  ]

  lifecycle {
    postcondition {
      condition     = self.result["token"] != null
      error_message = "Admin user creation failed or timed out. TFE may need manual initialization via the web UI."
    }
  }
}

### Build custom TFE agent image
resource "kubectl_manifest" "tfe_agent_image_stream" {
  yaml_body = <<-YAML
    apiVersion: image.openshift.io/v1
    kind: ImageStream
    metadata:
      name: tfe-agent-ibmcloud
      namespace: ${kubernetes_namespace_v1.tfe.metadata[0].name}
    spec:
      lookupPolicy:
        local: false
  YAML
}

resource "kubectl_manifest" "tfe_agent_build_config" {
  yaml_body = <<-YAML
    apiVersion: build.openshift.io/v1
    kind: BuildConfig
    metadata:
      name: tfe-agent-ibmcloud
      namespace: ${kubernetes_namespace_v1.tfe.metadata[0].name}
    spec:
      source:
        type: Dockerfile
        dockerfile: |
          FROM hashicorp/tfc-agent
          USER root
          RUN mkdir /.tfc-agent && chmod 770 /.tfc-agent
          RUN chmod -R 777 /home

          # Download and install oc
          RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz -o oc.tar.gz && \
          tar -xvzf oc.tar.gz -C /usr/local/bin oc && \
          tar -xvzf oc.tar.gz -C /usr/local/bin kubectl && \
          rm oc.tar.gz

          # Verify installation
          RUN oc version --client

          # Install the ibmcloud CLI & all plugins
          RUN curl -fsSL https://clis.cloud.ibm.com/install/linux | sh && \
          ibmcloud config --check-version=false && \
          chmod +x $(which ibmcloud) && \
          ibmcloud plugin install -a -f

          USER tfc-agent
      strategy:
        type: Docker
        dockerStrategy:
          from:
            kind: DockerImage
            name: hashicorp/tfc-agent
      output:
        to:
          kind: ImageStreamTag
          name: tfe-agent-ibmcloud:latest
      triggers:
        - type: ConfigChange
  YAML
}

data "kubernetes_resource" "tfe_agent_image_stream" {
  depends_on  = [kubectl_manifest.tfe_agent_image_stream, kubectl_manifest.tfe_agent_build_config]
  api_version = "image.openshift.io/v1"
  kind        = "ImageStream"
  metadata {
    name      = "tfe-agent-ibmcloud"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }
}

data "kubernetes_resource" "tfe_route" {
  depends_on  = [kubectl_manifest.tfe_route]
  api_version = "route.openshift.io/v1"
  kind        = "Route"
  metadata {
    name      = local.route_name
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }
}

data "kubernetes_secret_v1" "tfe_admin_token" {
  depends_on = [data.external.admin_user_token]
  metadata {
    name      = "tfe-admin-token"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "tfe_admin_token" {
  depends_on = [data.external.admin_user_token]

  metadata {
    name      = "tfe-admin-token"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }
  data = {
    token = (
      data.external.admin_user_token.result["token"] != null && data.external.admin_user_token.result["token"] != "" && data.external.admin_user_token.result["token"] != "-1"
      ? data.external.admin_user_token.result["token"]
      : (try(data.kubernetes_secret_v1.tfe_admin_token.data.token, ""))
    )
  }
  type = "Opaque"

  # Ignore data token, if it exists, the data.kubernetes_secret is unknown at apply
  # It has just be read from the secret... so no need to write it.
  lifecycle {
    ignore_changes = [
      data["token"],
    ]
  }
}

# Use scrupt to create TFE organization
# This is a workaround to avoid using the TFE provider which attempt to evaluate the token and host before the deployment is created
resource "null_resource" "tfe_org" {
  count = var.tfe_organization != null && length(trimspace(var.tfe_organization)) > 0 ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_org.sh ${kubernetes_secret_v1.tfe_admin_token.data.token} ${var.tfe_organization} ${var.admin_email} ${data.kubernetes_resource.tfe_route.object.status.ingress[0].host}"
  }
}
