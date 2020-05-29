#############
# Providers #
#############

provider "azurerm" {
  version = ">=2.0.0"
  subscription_id = "example"
  features {}
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
  cost_center         = "example"
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

module "virtual_network" {
  source = "github.com/Azure-Terraform/terraform-azurerm-virtual-network.git?ref=v1.0.0"

  naming_rules = module.rules.yaml

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  names               = module.metadata.names
  tags                = module.metadata.tags

  address_space = ["192.168.123.0/24"]

  subnets = {
    "01-iaas-private"     = ["192.168.123.0/27"]
    "02-iaas-public"      = ["192.168.123.32/27"]
    "03-iaas-outbound"    = ["192.168.123.64/27"]
  }
}

##################
# Terraform Code #
##################

resource "azurerm_public_ip" "bastion" {
  name                = "${module.metadata.names.product_name}-bastion-public"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  allocation_method   = "Static"
  sku                 = "Basic"

  tags                = module.metadata.tags
}

resource "azurerm_network_interface" "bastion" {
  name                = "${module.metadata.names.product_name}-bastion"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  ip_configuration {
    name                          = "bastion"
    subnet_id                     = module.virtual_network.subnet["iaas-outbound-subnet"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }

  tags                = module.metadata.tags
}

resource "azurerm_network_security_rule" "bastion_in" {
  name                        = "bastion-in"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_network_interface.bastion.private_ip_address
  resource_group_name         = module.resource_group.name
  network_security_group_name = module.virtual_network.subnet_nsg_names["iaas-outbound-subnet"]
}

resource "azurerm_linux_virtual_machine" "bastion" {
  name                = "${module.metadata.names.product_name}-bastion"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"

  network_interface_ids = [
    azurerm_network_interface.bastion.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

output "ssh_command" {
  value = "ssh adminuser@${azurerm_public_ip.bastion.ip_address}"
}
