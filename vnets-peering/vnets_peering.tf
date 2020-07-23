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
  address_space       = ["192.168.123.0/24"]
  subnets = {
    "01-iaas-private"     = ["192.168.123.0/27"]
    "02-iaas-public"      = ["192.168.123.32/27"]
    "03-iaas-outbound"    = ["192.168.123.64/27"]
  }
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
  address_space = ["192.178.123.0/24"]
  subnets = {
    "01-iaas-private"     = ["192.178.123.0/27"]
    "02-iaas-public"      = ["192.178.123.32/27"]
    "03-iaas-outbound"    = ["192.178.123.64/27"]
  }
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

# Pub IP for VM-1
resource "azurerm_public_ip" "bastion" {
  name                = "${module.metadata.names.product_name}-bastion-public"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  allocation_method   = "Static"
  sku                 = "Basic"

  tags                = module.metadata.tags
}

# Pub IP for VM-2
resource "azurerm_public_ip" "bastion2" {
  name                = "${module.metadata_vnet2.names.product_name}-bastion2-public"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  allocation_method   = "Static"
  sku                 = "Basic"

  tags                = module.metadata_vnet2.tags
}

# Nic for VM-1
resource "azurerm_network_interface" "bastion" {
  name                = "${module.metadata.names.product_name}-bastion"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  ip_configuration {
    name                          = "bastion"
    subnet_id                     = module.vnet1.subnet["iaas-private-subnet"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }

  tags                = module.metadata.tags
}

# Nic for VM-2
resource "azurerm_network_interface" "bastion2" {
  name                = "${module.metadata_vnet2.names.product_name}-bastion2"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  ip_configuration {
    name                          = "bastion2"
    subnet_id                     = module.vnet2.subnet["iaas-private-subnet"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion2.id
  }

  tags                = module.metadata_vnet2.tags
}

# NetSec Rule for VM-1
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
  network_security_group_name = module.vnet1.subnet_nsg_names["iaas-private-subnet"]
}

# NetSec rule to allow for outbound
resource "azurerm_network_security_rule" "bastion_out" {
  name                        = "bastion-out"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = azurerm_network_interface.bastion.private_ip_address
  destination_address_prefix  = "*"
  resource_group_name         = module.resource_group.name
  network_security_group_name = module.vnet1.subnet_nsg_names["iaas-private-subnet"]
}

# NetSec Rule for VM-2
resource "azurerm_network_security_rule" "bastion2_in" {
  name                        = "bastion2-in"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_network_interface.bastion2.private_ip_address
  resource_group_name         = module.resource_group.name
  network_security_group_name = module.vnet2.subnet_nsg_names["iaas-private-subnet"]
}

# Create VM-1
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

# Create VM-2
resource "azurerm_linux_virtual_machine" "bastion2" {
  name                = "${module.metadata_vnet2.names.product_name}-bastion2"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"

  network_interface_ids = [
    azurerm_network_interface.bastion2.id,
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

output "ssh_command2" {
  value = "ssh adminuser@${azurerm_public_ip.bastion2.ip_address}"
}
