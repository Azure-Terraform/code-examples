# HashiCorp Vault AKS Deplyoment Example
This example will deploy a HashiCorp Vault cluster in AKS complete SSL encrypted ui

All modules used in this example are version locked.
We recommend checking for new versions before using this code.
&nbsp;

### Workflow Breakdown

 1.  Obtain subscription data (subscription)
 2.  Define tags and names (metadata)
 3.  Create resource group (resource_group)
 4.  Create AKS cluster (kubernetes)
 5.  Add kubernetes node pool
 6.  Add support for pod identity (aad_pod_identity)
 7.  Add dns zone (dns)
 8.  Provision public_ip and set dns record
 9.  Provision cert manager on AKS cluster (cert_manager)
 10. Create lets-encrypt certificate (certificate) 
 11. Create Nginx ingress controller (nginx_ingress)
 12. Create HashiCorp Vault cluster (vault)
