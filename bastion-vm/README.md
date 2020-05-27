# Azure Bastion Virtual Machine Deplyoment Example
This example will deploy a virtual network in Azure.

All modules used in this example are version locked.
We recommend checking for new versions before using this code.
&nbsp;

### Workflow Breakdown

 1. Obtain subscription data (subscription)
 2. Define tags and names (metadata)
 3. Create resource group (resource_group)
 4. Create virtual network (virtual_network)
 5. Create public ip (azurerm_public_ip)
 6. Create network interaface (azurerm_network_interface)
 7. Create ingress security rule (azure_network_security_rule)
 8. Create virtual machine (azurerm_linux_virtual_machine)
 9. Output connection info (output)
