<#
    .DESCRIPTION
        An example runbook which gets all the ARM resources using the Run As Account (Service Principal)
        Then for each resource group, get all of the VMs and get the status
        If the Status is Stopped...billing is still occurring, so this will deallocate these.

    .NOTES
        AUTHOR: Brian Sherwin
        LASTEDIT: Dec 14, 2016
#>

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$RGs = Get-AzureRMResourceGroup
foreach($RG in $RGs)
{
    write-output ("ResourceGroup: " + $RG.ResourceGroupName)
    $VMs = Get-AzureRmVM -ResourceGroupName $RG.ResourceGroupName
    foreach($VM in $VMs)
    {
        $VMDetail = Get-AzureRmVM -ResourceGroupName $RG.ResourceGroupName -Name $VM.Name -Status
        foreach ($VMStatus in $VMDetail.Statuses)
        { 
            $VMStatusDetail = $VMStatus.DisplayStatus
            if($VMStatus.Code.CompareTo("PowerState/stopped") -eq 0)
            {
                write-output ("Need to deallocate " + $VM.Name + " because it was stopped.")
                <#Stop-AzureRmVM -ResourceGroupName $RG.ResourceGroupName -Name $VM.Name -force#>
                Invoke-AzureRmResourceAction -ResourceGroupName $RG.ResourceGroupName -ResourceType Microsoft.Compute/virtualMachines -ResourceName $VM.Name -Action deallocate -ApiVersion 2016-03-30 -Force
                write-output ("Deallocated " + $VM.Name + " because it was stopped.")
            }
        }
        write-output $VM.Name $VMStatusDetail
    }
}