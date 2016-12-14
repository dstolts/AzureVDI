# Select Azure Account, Select Resource group or optionally create new resource group
# Includes checking for multiple subscriptions before offering to select subscription.  If only one, then uses it.

#region Evaluate Parameters; Create Defaults Values

Param (
    [Parameter(Mandatory=$false,
                    Position=0,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
    [Alias("Name")]
    [string[]]$ComputerName=$env:COMPUTERNAME,
    [string[]]$AzureRunAs="AzureRunAsConnection" ,
    [Parameter(Mandatory=$false)][string]$RGName,                 # Pops List to select default
    [Parameter(Mandatory=$false)][string]$Location,               # Defaults to Location of Resource Group
    [Parameter(Mandatory=$false)][string]$SubscriptionID          # Subscription to create RG in
) 


write-host "Using Service Account Credentials from = 
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $AzureRunAs         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
} 

# Sign-in with Azure account credentials
Try
{
    # Probably want to change this to certificate auth
    Write-Host "Checking Azure Login"
    $TestSubscription = Get-AzureRmSubscription
    #Get-WMIObject Win32_Service -ComputerName localhost -Credential (Get-Credential) -ErrorAction "Stop"
}
Catch [Exception]
{
    Write-Host "Need to Login"
    # Sign-in with Azure account credentials
    $AzureLogin = Login-AzureRmAccount
    Write-Host "Logged into Azure" -ForegroundColor Green
    #    Write-Host $_
    #    $_ | Select *
}

#Check if parameters supplied  
If ($SubscriptionID -eq "") {
  # See how many subscriptions are available... 
  $mySubscriptions = Get-AzureRmSubscription
  $SubscriptionID = $mySubscriptions[0]  # just grab the first one for now...
  If ($mySubscriptions.Count -gt 1) { 
    Write-Host "Select SubscriptionID from the popup list." -ForegroundColor Yellow
    $subscriptionId = 
        (Get-AzureRmSubscription |
         Out-GridView `
            -Title "Select an Azure Subscription …" `
            -PassThru).SubscriptionId
  }
}

$mySubscription=Select-AzureRmSubscription -SubscriptionId $subscriptionId
$SubscriptionName = $mySubscription.Subscription.SubscriptionName
Write-Host "Subscription: $SubscriptionName $subscriptionId " -ForegroundColor Green

If ($RGName -eq "") {
    # have user select RG
    Write-Host "Select Resource Group from the list.  If you cancel, you will be given the option to create a new one" -ForegroundColor Yellow
    $myRG = (Get-AzureRmResourceGroup |
         Out-GridView `
            -Title "Select an Azure Resource Group; Press <ESC> <Cancel> to create new…" `
            -PassThru)
    If (!($myRG -eq $null)) {
        $RGName = $myRG.ResourceGroupName  # Grab the ResourceGroupName
        $Location = $myRG.Location       # Grab the ResourceGroupLocation (region)
    }  #else user pressed escape, will need to create RG 





}
# make sure the RG exists
$RgExists = Get-AzureRmResourceGroup | Where {$_.ResourceGroupName -eq $RGName }  # See if the RG exists.  If user pressed escape on drop box or passed a name that does not exist

# Make sure the RG Exists.  Create it if it does not (user pressed cancel above)
If (!($RgExists)) {
   write-host "Need to create New Resource Group " -ForegroundColor Yellow
   Write-Host "Select Region from the list to use for Resource Group" -ForegroundColor Yellow
   If ($Location -eq "") {
        # Select Azure regions
        $regions = Get-AzureLocation  
        $Location =  $regions.Name | 
             Out-GridView `
                -Title "Select Azure Datacenter Region …" `
                -PassThru
    }
    Write-Host "Location: $Location " -ForegroundColor Green
    If ($RGName -eq "") {
        $RGName = Read-Host -Prompt 'What Name would you like to give your new Resource Group?'
    }
} 
Write-Host "ResourceGroup $RGName in $Location on Account $SubscriptionID" -ForegroundColor Green
