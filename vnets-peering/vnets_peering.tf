provider "azurerm" {
  version = ">=2.0.0"
  features {}
}

# Subscription
module "subscription" {
  source = "git@github.com:Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = var.subscription_id
}

module "rules" {
  source = "git@github.com:openrba/python-azure-naming.git?ref=tf"
}

# Metadata
module "metadata" {
  source = "git@github.com:Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.0.0"

  subscription_id     = module.subscription.output.subscription_id
  # These values should be taken from https://github.com/openrba/python-azure-naming
  naming_rules        = module.rules.yaml
  business_unit       = "iog"
  environment         = "sandbox"
  location            = "useast2"
  market              = "us"
  product_name        = "vnet1"
  product_group       = "vnet1"
  project             = "https://gitlab.ins.risk.regn.net/example/"
  sre_team            = "iog-core-services"
  subscription_type   = "dev"
  resource_group_type = "app"

  additional_tags = {
    "project" = "demo"
  }
}

# Resource group
module "resource_group" {
  source = "git@github.com:Azure-Terraform/terraform-azurerm-resource-group.git?ref=v1.0.0"

  location = module.metadata.location
  tags     = module.metadata.tags
  names     = module.metadata.names
}

# Vnet1
module "vnet1" {
  source              = "git@github.com:Azure-Terraform/terraform-azurerm-virtual-network.git"
  naming_rules        = module.rules.yaml
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  names               = module.metadata.names
  tags                = module.metadata.tags
  address_space       = ["10.0.2.0/24"]
  subnets             = {}   
}

# Vnet-2
# Metadata
module "metadata_vnet2" {
  source = "git@github.com:Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.0.0"

  subscription_id     = module.subscription.output.subscription_id
  # These values should be taken from https://github.com/openrba/python-azure-naming
  naming_rules        = module.rules.yaml
  business_unit       = "iog"
  environment         = "sandbox"
  location            = "useast2"
  market              = "us"
  product_name        = "vnet2"
  product_group       = "vnet2"
  project             = "https://gitlab.ins.risk.regn.net/example/"
  sre_team            = "iog-core-services"
  subscription_type   = "dev"
  resource_group_type = "app"

  additional_tags = {
    "project" = "demo"
  }
}

module "vnet2" {
  source              = "git@github.com:Azure-Terraform/terraform-azurerm-virtual-network.git"
  naming_rules        = module.rules.yaml
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  names               = module.metadata_vnet2.names
  tags                = module.metadata_vnet2.tags
  address_space       = ["10.0.3.0/24"]
  subnets             = {}   
}

# Create Peering
module "peering" {
  source              = "git@github.com:openrba/azure-vnet-peering-existing-resources.git"
  subscription_id     = module.subscription.output.subscription_id
  source_peer         = {
      resource_group_name  = module.resource_group.name
      virtual_network_name = module.vnet1.vnet.name
  }
  destination_peer    = {
      resource_group_name  = module.resource_group.name
      virtual_network_name = module.vnet2.vnet.name
  }
}
