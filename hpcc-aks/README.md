# HPCC AKS Deplyoment Example
This example will deploy a default HPCC cluster to Azure Kubernetes service.

All modules used in this example are version locked.
We recommend checking for new versions before using this code.
&nbsp;

### Workflow Breakdown

 1. Obtain subscription data (subscription)
 2. Define tags and names (metadata)
 3. Create resource group (resource_group)
 4. Azure kubernetes deployment (kubernetes)
 5. Helm install for HPCC
 6. Output of useful commands
 
&nbsp;

### Original Instructions
This cluster was built using instructions from the HPCC Systems blog:
https://hpccsystems.com/blog/default-azure-setup