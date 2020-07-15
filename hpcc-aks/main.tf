variable "subscription_id" {
  default = "example"
}

#############
# Providers #
#############

provider "azurerm" {
  version = ">=2.0.0"
  subscription_id = var.subscription_id
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
  subscription_id = var.subscription_id
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

module "kubernetes" {
  source = "github.com/Azure-Terraform/terraform-azurerm-kubernetes.git?ref=v1.2.0"

  kubernetes_version = "1.18.2"
  
  location                 = module.metadata.location
  names                    = module.metadata.names
  tags                     = module.metadata.tags
  resource_group_name      = module.resource_group.name

  default_node_pool_name                = "default"
  default_node_pool_vm_size             = "Standard_D2s_v3"
  default_node_pool_enable_auto_scaling = true
  default_node_pool_node_min_count      = 1
  default_node_pool_node_max_count      = 5
  default_node_pool_availability_zones  = [1,2,3]

  enable_kube_dashboard = true
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
  version    = "7.10.2"

  set {
    name  = "global.image.version"
    value = "latest"
  }

  set {
    name  = "storage.dllStorage.storageClass"
    value = "azurefile"
  }

  set {
    name  = "storage.daliStorage.storageClass"
    value = "azurefile"
  }

  set {
    name  = "storage.dataStorage.storageClass"
    value = "azurefile"
  }

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

output "aks_login" {
  value = "az aks get-credentials --name ${module.kubernetes.name} --resource-group ${module.resource_group.name}"
}

output "aks_browse"{
  value = "az aks browse --name ${module.kubernetes.name} --resource-group ${module.resource_group.name}"
}