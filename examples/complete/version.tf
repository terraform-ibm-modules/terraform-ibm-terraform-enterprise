terraform {
  required_version = ">= 1.9.0"

  # Ensure that there is always 1 example locked into the lowest provider version of the range defined in the main
  # module's version.tf (basic and add_rules_to_sg), and 1 example that will always use the latest provider version (advanced, fscloud and multiple mzr).
  required_providers {
    ibm = {
      source  = "ibm-cloud/ibm"
      version = "2.7.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "2.0.1"
    }
  }
}
