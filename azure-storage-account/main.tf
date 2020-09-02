provider "azurerm" {
  version = ">=2.0.0"
  features {}
  alias   = "azurerm-provider"
}

module "subscription" {
  source = "github.com/Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = var.subscription_id
  providers = {
    azurerm = azurerm.azurerm-provider
  }
}

module "rules" {
  source = "git@github.com:openrba/python-azure-naming.git?ref=tf"
}

module "metadata"{
  source = "github.com/Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.1.0"
  naming_rules = module.rules.yaml
  providers = {
    azurerm = azurerm.azurerm-provider
  }
  market              = var.market
  project             = var.project
  location            = var.location
  sre_team            = var.sre_team
  environment         = var.environment
  product_name        = var.product_name
  business_unit       = var.business_unit
  product_group       = var.product_group
  subscription_id     = module.subscription.output.subscription_id
  subscription_type   = "nonprod"
  resource_group_type = "app"
}

module "resource_group" {
  source = "github.com/Azure-Terraform/terraform-azurerm-resource-group.git?ref=v1.0.0"
  providers = {
    azurerm = azurerm.azurerm-provider
  }
  location = module.metadata.location
  names    = module.metadata.names
  tags     = module.metadata.tags
}

module "create-storage-account" {
    source = "git@github.com:openrba/terraform-azurerm-storage-account.git?ref=dev"
    providers = {
        azurerm = azurerm.azurerm-provider
    }
    # Pass all the variables the module required
    resource_group           = module.resource_group.name
    location                 = module.metadata.location
    storage_account          = var.storage_account
    account_kind             = var.account_kind
    account_tier             = var.account_tier
    replication_type         = var.replication_type
    access_tier              = var.access_tier
    allow_blob_public_access = var.allow_blob_public_access
    authorized_subnets       = var.authorized_subnets
    tags                     = module.metadata.tags
    retention_days           = var.retention_days
}
