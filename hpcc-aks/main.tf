#############
# Providers #
#############

provider "azurerm" {
  version = ">=2.0.0"
  subscription_id = "example"
  features {}
}

provider "helm" {
  alias = "aks"
  kubernetes {
    host                   = module.kubernetes.host
    client_certificate     = base64decode(module.kubernetes.client_certificate)
    client_key             = base64decode(module.kubernetes.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
  }
}

#####################
# Pre-Build Modules #
#####################

module "subscription" {
  source = "github.com/Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = "example"
}

module "rules" {
  source = "git@github.com:openrba/python-azure-naming.git?ref=tf"
}

module "metadata"{
  source = "github.com/Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.0.0"

  naming_rules = module.rules.yaml
  
  market              = "us"
  project             = "example"
  location            = "useast2"
  sre_team            = "example"
  environment         = "sandbox"
  product_name        = "example"
  business_unit       = "example"
  product_group       = "example"
  subscription_id     = module.subscription.output.subscription_id
  subscription_type   = "nonprod"
  resource_group_type = "app"
}

module "resource_group" {
  source = "github.com/Azure-Terraform/terraform-azurerm-resource-group.git?ref=v1.0.0"
  
  location = module.metadata.location
  names    = module.metadata.names
  tags     = module.metadata.tags
}

module "app_reg" {
  source = "github.com/Azure-Terraform/terraform-azuread-application-registration.git?ref=v1.0.0"

  names    = module.metadata.names
  tags     = module.metadata.tags
}

module "kubernetes" {
  source = "github.com/Azure-Terraform/terraform-azurerm-kubernetes.git?ref=v1.0.1"
  
  location                 = module.metadata.location
  names                    = module.metadata.names
  tags                     = module.metadata.tags
  kubernetes_version       = "1.18.2"
  resource_group_name      = module.resource_group.name
  service_principal_id     = module.app_reg.application_id
  service_principal_name   = module.app_reg.service_principal_name
  service_principal_secret = module.app_reg.service_principal_secret
}

###############
# HPCC Deploy #
###############

resource "helm_release" "hpcc" {
  provider    = helm.aks

  name       = "mycluster"
  namespace  = "default"
  repository = "https://hpcc-systems.github.io/helm-chart/"
  chart      = "hpcc"

  values = [
    "${file("values.yaml")}"
  ]
}

##########
# Output #
##########
output "resource_group_name" {
  value = module.resource_group.name
}

output "aks_cluster_name" {
  value = module.kubernetes.name
}
