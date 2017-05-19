Param(
[string]$1,
[string]$2
)
# usage ./captureimage.ps1 ResourceGroupName VMName
#$1 = Resource
#$2 = Image URL

$imageURL = "https://hackathontempstorage.blob.core.windows.net/images/Hackathon120161213133540.vhd"

Login-AzureRmAccount
$sshKeyData = "ssh ENTER YOUR ssh KEY HERE!"
#Create UniqueID for StorageAccount
#$uniq_user = $env:USERPROFILE.Split('\')[2]
#$azunique = -join ([char[]](48..57+97..122)*100 | Get-Random -Count 12)
#$azstoreid = $uniq_user + $azunique
#echo "Your azstoreid is $azstoreid"

# DEBUG then you can test it with...
#   (azure storage account check -v $azstoreid) 

#Resource Group Create

#New-AzureRMResourceGroup $1 eastus

#Write-Output "Created resource group: $1"

#Create StorageAcct Parameters JSON file

#If ($StorageAccountName -eq "") {  # we do not know what storage account they want to open so let's pop a list
  # See how many storage accounts are available... 
  $myStorage = Get-AzureRmStorageAccount  # Get the Storage Account List
  $StorageAccount = $myStorage[0]  # just grab the first one for now...
  # In a future version, may want to add error checking.  Will crash if no storage accounts in current $rgName
  If ($myStorage.Count -gt 1) { 
    Write-Host "Select Storage Account from the popup list." -ForegroundColor Yellow
    $StorageAccount = 
        ($myStorage |
         Out-GridView `
            -Title "Select an Azure Storage Account …" `
            -PassThru)
    If (!($StorageAccount -eq $null)) {
        $RGName = $StorageAccount.ResourceGroupName  # Grab the ResourceGroupName from the storage account
        $Location = $StorageAccount.Location       # Grab the ResourceGroupLocation (region) from the storage account
        $StorageAccountName = $StorageAccount.StorageAccountName # Grab the StorageAccountName 
    }  #else user pressed escape
  }
#}

Write-Host "Checking Resource Group"  
#If ($RGName -eq "") {  # StorageAccountName was passed in as a parameter but the RGName was not.
    # have user select RG
    Write-Host "Select Resource Group from the list." -ForegroundColor Yellow
    $myRG = (Get-AzureRmResourceGroup |
         Out-GridView `
            -Title "Select an Azure Resource Group" `
            -PassThru)
    If (!($myRG -eq $null)) {
        $RGName = $myRG.ResourceGroupName  # Grab the ResourceGroupName
        $Location = $myRG.Location       # Grab the ResourceGroupLocation (region)
    }  #else user pressed escape
#}
Write-Host "ResourceGroup $RGName in $Location" -ForegroundColor Green



Write-Output @" 
{
  "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "storageAccountType": {
      "value": "Standard_LRS"
    },
    "storageAccountName": {
      "value": "$StorageAccountName"
    }
  }
} 
"@ > ".\CustStorageAcct.parameters.json"

Write-Output "Created Storage templates\CustStorageAcct.Parameters.json"

# New Azure Deployment
# Splat prop for deployment
$prop = @{
    Name = $StorageAccountName;
    ResourceGroupName = $RGName;
    TemplateFile = ".\CustStorageAcct.json";
    TemplateParameterFile = ".\CustStorageAcct.parameters.json"

}

New-AzureRmResourceGroupDeployment @prop

# End Azure Deployment Part 1

### Azure Storage Connection and copy ###

#Destination VHD - Image VHD Name
$destBlob = "customimage.vhd"

#Destination container name
$destContainerName = "customimage"

#Get Destination storage account key
$destKey = Get-AzureRmStorageAccountKey $RGName $StorageAccountName
$destStorageKey = ($destKey.value -split '\n')[0]
echo "Destination key: $destStorageKey"

## Create Destination context for authenticating the copy
$destContext = New-AzureStorageContext -StorageAccountName $StorageAccountName `
                                       -StorageAccountKey $destStorageKey

## Create the detination container in storage account
New-AzureStorageContainer -Name $destContainerName `
                          -Context $destContext 
                                
### Start Asynchronus Copy ###
$blobcopy = @{
        AbsoluteUri = $imageURL
        DestBlob = $destBlob
        DestContainer = $destContainerName
        DestContext = $destContext
}

$blob = Start-AzureStorageBlobCopy @blobcopy

Write-Output "Copying master image to your local account..."

### Check Status of Blob Copy ###
$status = Get-AzureStorageBlobCopyState -Blob $destBlob -Container $destContainerName -Context $destContext

## Print status of Blob copy state ##
$status

### Loop until complete
While($status.Status -eq "Pending"){
    $status = Get-AzureStorageBlobCopyState -Blob $destBlob -Container $destContainerName -Context $destContext
    Start-Sleep 10
    ### Print out status ###
    $status
}

#Image URI Output
$storBlob = Get-AzureStorageBlob -Container $destContainerName -Context $destContext
$destBlob = $storBlob.Name
$ImageURI = (Get-AzureStorageBlob -Context $destContext -blob $destBlob -Container $destContainerName).ICloudBlob.uri.AbsoluteUri
Write-output "Your local copy image URI is: $ImageURI"

## Image path for CustomImageName in Custom Gold Parameters JSON Template
#$IMAGE_PATH = $storBlob.Name.Split('/')[3]
#Write-Output "Your Image Path is: $IMAGE_PATH"

## Custom Gold Parameters Json Creation
Write-Output @"
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "adminUserName": {
      "value": "customimage"
    },
    "sshKeyData": {
      "value": "$sshKeyData"
    },
    "vmSize": {
      "value": "Standard_DS1"
    },
    
    "customImageName": {
      "value": "$destBlob"
    },
    "storageAccountName": {
      "value": "$StorageAccountName"
    },
    "newVmName": {
      "value": "CustomVM"
    },
    "vhdStorageAccountContainerName": {
      "value": "$destContainerName"
    }
   }
}
"@ > .\CustomGoldVM.parameters.json

Write-Output "Created Storage .\CustomGoldVM.Parameters.json"
## End Custom Gold Parameters Json Creation

# Begin Azure Deployment Part 2
# Deployment Splat
$param = @{
    Name = "VmDepl";
    ResourceGroupName = $RGName;
    TemplateFile = ".\CustomGoldVM.json";
    TemplateParameterFile = ".\CustomGoldVM.parameters.json"

}

New-AzureRmResourceGroupDeployment @param 
# End Azure Deployment Part 2