## ALIP
Accenture ALIP VDI integration.


## Resources
#### Connecting networks across resource groups or subscriptions :
Configure a VNet-to-VNet connection for Resource Manager using PowerShell

https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal

## Azure Automation Scripts
Creating an Azure Automation Account will create an "Azure Run As" account that will be used in the runbook to authenticate and run the AzureRm* scripts below.

Deallocate-StoppedVMs.ps1
> An example script which gets all the ARM resources using the Run As Account (Service Principal). Then for each resource group, get all of the VMs and get the status. If the Status is Stopped...billing is still occurring, so this script will deallocate these.