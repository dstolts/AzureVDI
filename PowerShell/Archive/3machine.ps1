$ErrorActionPreference = "continue"  #continue, stop or SilentlyContinue
#region Introduction
<#  
================================================================================
========= Introduction to BuildMyLab.ps1 =======================================
================================================================================
 Name: BuildMyLab.ps1
 Purpose: Build infrastructure on Azure needed for IT-Camp labs and demos
 Author: Dan Stolts - dstolts@microsoft.com - http://ITProGuru.com
 		Contributors/Special Thanks: 
			* Matt Hester - http://blogs.technet.com/b/matthewms/
			* Rick Clause - http://about.me/rickclaus http://regularitguy.com/
			Syntax/Execution:  Simply Copy entire script contents and paste into PowerShell (or ISE) :) 
						Then follow on-screen prompts (or run as a .ps1)
 Description: 
 		Prompts user through collecting of prerequisite information, Connects to Azure
       Allows user to set various variables (computer name, OS Image, Creds, etc)
       Downloads additional supporting files needed (post configuration scripts)
 		Builds a script to "undo" or "remove" all the infrastructure the script creates 
         (except network, which the code is there but remarked out)
       Builds the Infrastructure on users Azure account.  Infrastructure includes: 
			Network, Cloud Service, Storage Account, Storage Container
       	3 Virtual Machines: 
				DC01 - Post configuration to deploy AD and use Static IP address
				WFE01 - No configuration done YET, Website files are downloaded to SQL Server F:
				SQL01 - SQL Configured with additional users, Adventure works Database (Test), 
					Firewall open, SQL security and defaults configured, Drives and folders configured
		Executes Configuration Scripts on servers (which were downloaded from IT-Camp Master site)
       Opens Azure Cleanup Script using Notepad.exe
		Entire environment is built in less than 10 mins script runtime 
 			complete configuration is another 10-15 mins for post configuration scripts to run (background)
 Disclaimer: Use at your own Risk!  See details at ITProGuru.com 
 Limitations: 
 		* Almost no error checking - error checking will be added in a future revision
		* Requires PowerShell and Azure Powershell Module (http://azure.microsoft.com/en-us/downloads/)
		* Not multi-language
		* Have seen problems if user has multiple registered azure accounts in Powershell.  
			This looks like a bug with the Command to Set-AzureSubscription Command
 		* Have seen problems with slow networks (timeout issues) where the command fails 
		due to perceived loss of connectivity to Azure
		* Timeout issues can arise if the Azure account is not performing well (which happens)
		* If you would like to turn on execution of scripts see either:
		   Powershell:	http://itproguru.com/expert/2015/01/powershell-script-to-create-registry-files-to-change-powershell-execution-policy/
		   Manual:		http://itproguru.com/expert/2012/01/how-to-create-enable-permissions-and-run-a-multi-line-powershell-script/
 Design Considerations:
		* Script can simply be copied into a Powershell window to run (do not need to have scripts enabled)
 		* Default values are all set in variables at the top of the script so they can be easily changed 
 		* Designed for Microsoft Evangelist or other EXPERTS to use; 
			Not designed for end-user / attendees.  
 			Attendees/Novice may use it but there is not enough help built in to overcome problems
		
================================================================================
#>
#endregion Introduction
#region Revision History
<#
================================================================================
================== Revision History ============================================
================================================================================
 2015-01-17 Dan Stolts: Version 1.0: Create Script
#>

#endregion Revision History
#region Wish List
#================================================================================
#================== Wish List / Feature Requests ================================
#================================================================================
# NOTE: all code is in this text file.  if you make any change yourself, please send it to dstolts@microsoft.com

# * Fix DNS (ping by internal host name) [ETA 2015/02]
# * hide password on form [ETA 2/2015]
# * allow user to change Post configuration script/location for each machine [ETA 2/2015]
# * allow user to change network subnet and IP configuration [ETA unknown]
# * add error checking [ETA unknown]
# * Allow many servers - Build array of servers and let user add as many as they want
# * Display Default Path on form and allow user to change
 
#endregion Wish List
#region BeforeYouBegin: 
#This #This script is for provisioning all the labs in FY15Q3 Azure IT Camp
#You may use variables at the top of the script to simplify setting default values when running the script.
#You will be prompted for all critical variables so all you have to do is dump the entire script into a powershell window
#endregion BeforYouBegin
#region Pre-Lab setup
#region Default Values
$StartTime = Get-Date
Write-Host (Get-Date) -ForegroundColor Green
$PublishSettings = $false
$ExecuteNow = $true
$ITCPath = ((Get-Item -Path ".\").FullName + "\")  #Set the default value for path
$ITCUniqueID = "abc123"
$ITCLocation = "East US 2"	 			#What Region do you want to use for your infrastructure?   
$ITCNetworkName = "TechNetwork"			#If you change Location or net name, you will also need to change the Network Config File to match
$ITCNetConfig = "TechNet.xml"
$adminusername = "SysAdmin"
$adminPassword = "Passw0rd!"

$ITCDC01Name = "DC01"
$ITCSQL01Name = "SQL01"
$ITCWFE01Name = "WEBFE01"
$ITCStoreName =  "itcstore" 
$ITCServiceName = "ITCservice"
$ITCDC01Image = 0
$ITCWFE01Image = 0
$ITCSQL01Image = 0
$ITCImage1Default = "Windows Server 2012 R2 Datacenter"
$ITCImage2Default = "Windows Server 2012 R2 Datacenter"
#$ITCImage1Default = "a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-201412.01-en.us-127GB.vhd"
#$ITCImage2Default = "a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-201412.01-en.us-127GB.vhd"
# For SQL Server we are using an image name instead of an image label.  This is to make sure we get a very consistent image
   $ITCImage3Default = "fb83b3509582419d99629ce476bcb5c8__SQL-Server-2014-RTM-12.0.2361.0-Enterprise-ENU-Win2012R2-cy14su05"
   #$ITCImage3Default = "SQL Server 2014 RTM Enterprise on Windows Server 2012 R2"

#$ITCImageName = (Get-AzureVMImage)[159].ImageName   # 2012 R2 Datacenter (Dec 2014) #a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-201412.01-en.us-127GB.vhd
# due to the row number changing every time new images are added we have to pull all rows into an array and check the number at runtime.
# the feature to select an image by imagename does not work reliably.
$ITCContainerName = "itc-files"
#endregion default values

#region Get-DefaultPath
	Write-Host (Get-Date) -ForegroundColor Green
    Write-Host "We need to download some supporting scripts.  Please select a folder where you would like them to be stored."  -ForegroundColor Green 
    Write-Host "We will later upload everything in that folder to your azure storage so we recommend you select a clean folder"  -ForegroundColor Green 
    Write-Host "If you cancel, we will take the current folder as the default"  -ForegroundColor Green 
    $object = New-Object -comObject Shell.Application   
    $folder = $object.BrowseForFolder(0, "Please select Upload/Download Folder location", 0)
    if ($folder -ne $null) {
        $ITCPath = $folder.self.Path.substring(0,$folder.self.path.length)    # Set the ITCPath
        if ($folder.self.path.substring($folder.self.path.length - 1, 1) -ne "\") {
            # Add Trailing backslash 
            $ITCPath = $folder.self.Path.substring(0,$folder.self.path.length) + "\"}     
        Write-Host $ITCPath "will be used for creating upload/download path" -ForegroundColor Green 
        Set-Location $ITCPath
    }
#endregion get-DefaultPath
#region connect to Azure
	Write-Host (Get-Date) -ForegroundColor Green
    # You can skip this section if your PowerShell is already configured to connect to Azure.
    # if you are not sure, you can just run it or test with the command Get-AzureVM
    Write-host "Would you like to download your PublishSettings File to connect to Azure? (Default is No)" -ForegroundColor Yellow
    $Readhost = Read-Host " ( y / n ) "
    Switch ($ReadHost)
     {
       Y {Write-host "Yes, Download PublishSettings"; $PublishSettings=$true}
       N {Write-Host "No, Skip PublishSettings"; $PublishSettings=$false}
       Default {Write-Host "Default, Skip PublishSettings"; $PublishSettings=$false}
     }
    if ($PublishSettings) {
        Write-Host "A Browser window should have opened for you to login." -ForegroundColor Yellow
        Write-Host "   We have to use the output of the Get-AzurePublishSettingsFile as input of the Import-AzurePublishSettingsFile" -ForegroundColor Green 
	    Write-Host "   You will be prompted to Save the AzurePublishSettingsFile.  "  -ForegroundColor Green 
	    Write-Host "      Make note where you save it because you will have to browse to it next"  -ForegroundColor Green 
	    Write-Host "Press ENTER after you have saved your publish settings file"  -ForegroundColor Green 
	    Get-AzurePublishSettingsFile
	    Pause
	    Write-Host "Thank You.  Now Please select your PublishSettings File"  -ForegroundColor Green 
	    $openFileDialog = New-Object windows.forms.openfiledialog  
	    $openFileDialog.initialDirectory = [System.IO.Directory]::GetCurrentDirectory()  
	    $openFileDialog.title = "Select PublishSettings Configuration File to Import"  
	    $openFileDialog.filter = "All files (*.*)| *.*"  
	    $openFileDialog.filter = "PublishSettings Files|*.publishsettings|All Files|*.*"
	    $openFileDialog.ShowHelp = $True  
	    Write-Host "Select Downloaded Settings File... (see FileOpen Dialog)" -ForegroundColor Green 
	    $result = $openFileDialog.ShowDialog()   
        $result
	    if($result -eq "OK")    {   
            Write-Host "Selected Downloaded Settings File:"  -ForegroundColor Green 
	        $openFileDialog.filename  
	        #Import-AzurePublishSettingsFile -PublishSettingsFile "<path and filename.publishsettings>"
	        Import-AzurePublishSettingsFile -PublishSettingsFile $openFileDialog.filename  
        }
        else { Write-Host "Import Settings File Cancelled!" -ForegroundColor Yellow}
    }
	Get-AzureSubscription  | format-table SubscriptionName, SubscriptionId
	Get-AzureAccount | Format-List  # this shows a list of available AzureAccounts
	Write-Host " Your subscriptions are listed.  " -ForegroundColor Green 
    Write-Host " If you have multiple subscriptions, we have seen problems running script ..." -ForegroundColor Green 
    Write-Host " If problems, and you have more than one Azure account listed above, " -ForegroundColor Yellow
    Write-Host "   use Remove-AzureAccount <AzureAccountID> to remove each/all the accounts." -ForegroundColor Yellow  
    Write-Host " When you re-run the script it will reimport the AzureAccount you need to use" -ForegroundColor Green
    Write-Host " If you still need help, contact Dan Stolts dstolts@microsoft.com)" -ForegroundColor Green 
    Write-Host ""
	Write-Host "Confirming we can connect to your Azure Account"  -ForegroundColor Green 
    Get-AzureVM       | Format-Table Name, Status, InstanceSize, PowerState 
    Write-Host "If you got an error here, something went wrong with your cert. CTRL-C to Break" -ForegroundColor Green
    Write-Host "If you got an error here, something went wrong with your cert. Otherwise continue" -ForegroundColor Yellow
	Pause
#endregion Connect to Azure
#region Get-Variables from User

Write-Host (Get-Date) -ForegroundColor Green
Write-Host "Building List of available OS Images" -ForegroundColor Green
$ArrayImage = Get-AzureVMImage 
Write-Host "Creating form to collect preferrences" -ForegroundColor Green
#Set-StrictMode -Version Latest
Add-Type -Assembly System.Windows.Forms     ## Load the Windows Forms assembly
## Create the main form
    $form = New-Object Windows.Forms.Form
    $form.Width = 900 ; $form.Height = 600 
    $form.FormBorderStyle = "FixedToolWindow"
    $form.Text = "Script Required Variable Selection"
    $form.StartPosition = "CenterScreen"

    ## Create the Label for UniqueID
    $lblUnique = New-Object System.Windows.Forms.Label  
        $lblUnique.Text = "What UniqueID would you like to use? (eg. DLS) letters and numbers only"; $lblUnique.Top = 5 ; $lblUnique.Left = 5; $lblUnique.Width=250 #;$lblUnique.AutoSize = $true
        $form.Controls.Add($lblUnique) 
        ## Create the TextBox for UniqueID
    $txtUnique = New-Object Windows.Forms.TextBox ; $txtUnique.Top = 35; $txtUnique.Left = 5; $txtUnique.Width = 90
        $txtUnique.Text = $ITCUniqueID 
        $form.Controls.Add($txtUnique)

    ## Subscription Name
    $lblSub = New-Object System.Windows.Forms.Label  
        $lblSub.Text = "Which Azure Subscription would you like to use?"; $lblSub.Top = 60; $lblSub.Left = 5; $lblSub.Autosize = $true 
        $form.Controls.Add($lblSub) 
        Write-Host "Building List of available subscriptions" -ForegroundColor Green
    # Listbox for Subscription Name
    $objListBox = New-Object System.Windows.Forms.ListBox 
        $objListBox.Top = 80; $objListBox.Left = 5; $objListBox.Height = 80
        #$objListBox.Items.Add("Test Do NOT USE")
        $SubArray = Get-AzureSubscription # | Format-list SubscriptionName, IsDefault, SubscriptionId
        foreach ($element in $SubArray) { [void] $objListBox.Items.Add($element.SubscriptionName)  }
        [void] $objListBox.SetSelected(0,$true)
        $form.Controls.Add($objListBox) 

    ## Computer1 DC01
    $lblCPU1 = New-Object System.Windows.Forms.Label  
    $lblCPU1.Text = "Server1 Name DC01"; $lblCPU1.Top = 160 ; $lblCPU1.Left = 5; $lblCPU1.Width=150 #;$lblCPU1.AutoSize = $true
    $form.Controls.Add($lblCPU1) 
    $txtCPU1 = New-Object Windows.Forms.TextBox ; $txtCPU1.Top = 158; $txtCPU1.Left = 160; $txtCPU1.Width = 90 
    $txtCPU1.Text = $ITCDC01Name
    $form.Controls.Add($txtCPU1)
    ## Create the OS Image ComboBox
    $cbImage1 = New-Object Windows.Forms.ComboBox ; $cbImage1.Top = 158; $cbImage1.Left = 270; $cbImage1.Width = 350
    [void] $cbImage1.BeginUpdate()
    $i = 0 ; $iSelect = -1
    foreach ($element in $ArrayImage) { 
        $thisElement = $i.ToString() +"::" + $element.label
        [void] $cbImage1.Items.Add($thisElement)
        if ($element.label -like ($ITCImage1Default+"*")) {
          Write-Host $i $element.label; 
          $cbImage1.Text = $i.ToString() +"::" +$element.label; 
          $iSelect = $i }      
          $i ++
        }
    $cbImage1.SelectedIndex = $iSelect
    [void] $cbImage1.EndUpdate()
    $form.Controls.Add($cbImage1)

    ## Computer2 WFE01
    $lblCPU2 = New-Object System.Windows.Forms.Label  
    $lblCPU2.Text = "Server2 Name WFE01"; $lblCPU2.Top = 190 ; $lblCPU2.Left = 5; $lblCPU2.Width=150 #;$lblCPU2.AutoSize = $true
    $form.Controls.Add($lblCPU2) 
    $txtCPU2 = New-Object Windows.Forms.TextBox ; $txtCPU2.Top = 188; $txtCPU2.Left = 160; $txtCPU2.Width = 90 
    $txtCPU2.Text = $ITCWFE01Name
    $form.Controls.Add($txtCPU2)
    ## Create the OS Image ComboBox
    $cbImage2 = New-Object Windows.Forms.ComboBox ; $cbImage2.Top = 188; $cbImage2.Left = 270; $cbImage2.Width = 350
    [void] $cbImage2.BeginUpdate()
    $i = 0 ; $iSelect = -1
    foreach ($element in $ArrayImage) {
        $thisElement = $i.ToString() +"::" + $element.label
        [void] $cbImage2.Items.Add($thisElement)
        if ($element.label -Like ($ITCImage2Default+"*")) { 
          Write-host $i $element.label; 
          $cbImage2.Text = $thisElement; 
          $iSelect = $i 
          $cbImage1.Text = $i.ToString() +"::" +$element.label }
        $i ++
        }
    $cbImage2.SelectedIndex = $iSelect
    [void] $cbImage2.EndUpdate()
    $form.Controls.Add($cbImage2)
    
    ## Computer3 SQL01
    $lblCPU3 = New-Object System.Windows.Forms.Label  
		$lblCPU3.Text = "Server3 Name SQL01"; $lblCPU3.Top = 220 ; $lblCPU3.Left = 5; $lblCPU3.Width=150 #;$lblCPU3.AutoSize = $true
		$form.Controls.Add($lblCPU3) 
		$txtCPU3 = New-Object Windows.Forms.TextBox ; $txtCPU3.Top = 218; $txtCPU3.Left = 160; $txtCPU3.Width = 90 
			$txtCPU3.Text = $ITCSQL01Name
			$form.Controls.Add($txtCPU3)
			## Create the OS Image ComboBox
			$cbImage3 = New-Object Windows.Forms.ComboBox ; $cbImage3.Top = 218; $cbImage3.Left = 270; $cbImage3.Width = 350
			[void] $cbImage3.BeginUpdate()
			$i = 0 ; $iSelect = -1
			foreach ($element in $ArrayImage) { 
				$thisElement = $i.ToString() +"::" + $element.label
				[void] $cbImage3.Items.Add($thisElement)
				if ($element.ImageName -eq $ITCImage3Default) {
				   $cbImage3.Text = $thisElement 
				   Write-host $i $element.label
				   Write-Host $Element.ImageName 
				  $iSelect = $i } # Set Default     $cbImage1.Text = $i.ToString() +"::" +$element.label
				$i ++
				}
			$cbImage3.SelectedIndex = $iSelect
			[void] $cbImage3.EndUpdate()
			$form.Controls.Add($cbImage3)

    ## Network Name
    $lblNetwork = New-Object System.Windows.Forms.Label  
		$lblNetwork.Text = "Network Name"; $lblNetwork.Top = 250 ; $lblNetwork.Left = 5; $lblNetwork.Width=150 #;$lblNetwork.AutoSize = $true
		$form.Controls.Add($lblNetwork) 
		$txtNetwork = New-Object Windows.Forms.TextBox ; $txtNetwork.Top = 248; $txtNetwork.Left = 160; $txtNetwork.Width = 90 
			$txtNetwork.Text = $ITCNetworkName
			$form.Controls.Add($txtNetwork)
			# Network Config FileName will just add .Config to the network name
    
    ## Credentials
    $lblUserName = New-Object System.Windows.Forms.Label  
		$lblUserName.Text = "Username / Password"; $lblUserName.Top = 280 ; $lblUserName.Left = 5; $lblUserName.Width=150 #;$lblUserName.AutoSize = $true
		$form.Controls.Add($lblUserName) 
		$txtUserName = New-Object Windows.Forms.TextBox ; $txtUserName.Top = 278; $txtUserName.Left = 160; $txtUserName.Width = 90 
			$txtUserName.Text = $adminusername
			$form.Controls.Add($txtUserName)
		$txtPassword = New-Object Windows.Forms.TextBox ; $txtPassword.Top = 278; $txtPassword.Left = 260; $txtPassword.Width = 90 
			$txtPassword.Text = $adminPassword
			$form.Controls.Add($txtPassword)

    ## Store
    $lblStorage = New-Object System.Windows.Forms.Label  
		$lblStorage.Text = "Storage Name"; $lblStorage.Top = 310 ; $lblStorage.Left = 5; $lblStorage.Width=150 #;$lblStorage.AutoSize = $true
		$form.Controls.Add($lblStorage) 
		$txtStorage = New-Object Windows.Forms.TextBox ; $txtStorage.Top = 308; $txtStorage.Left = 160; $txtStorage.Width = 90 
			$txtStorage.Text = $ITCStoreName 
			$form.Controls.Add($txtStorage)


    ## Cloud Service
    $lblService = New-Object System.Windows.Forms.Label  
		$lblService.Text = "Cloud Service Name"; $lblService.Top = 340 ; $lblService.Left = 5; $lblService.Width=150 #;$lblService.AutoSize = $true
		$form.Controls.Add($lblService) 
		$txtService = New-Object Windows.Forms.TextBox ; $txtService.Top = 338; $txtService.Left = 160; $txtService.Width = 90 
			$txtService.Text = $ITCServiceName 
			$form.Controls.Add($txtService)

    ## Location Name
    $lblLoc = New-Object System.Windows.Forms.Label  
		$lblLoc.Text = "Azure LOCATION"; $lblLoc.Top = 370; $lblLoc.Left = 5; $lblLoc.Autosize = $true 
		$form.Controls.Add($lblLoc) 
		Write-Host "Building List of available Locations" -ForegroundColor Green
		# Listbox for Location Name
		$locListBox = New-Object System.Windows.Forms.ListBox 
			$locListBox.Top = 395; $locListBox.Left = 5; $locListBox.Height = 120
			#$objListBox.Items.Add("Test Do NOT USE")
			$LocArray = Get-AzureLocation # | Format-list SubscriptionName, IsDefault, SubscriptionId
			$i=0
			foreach ($element in $LocArray) { 
				[void] $locListBox.Items.Add($element.name)
				if ($element.name -eq $ITCLocation) { [void] $locListBox.SetSelected($i,$true) } # Set Default
				$i ++
			}
			$form.Controls.Add($locListBox) 

	Write-Host "Finalizing Form" -foregroundcolor green

    ## Create the button panel to hold the OK and Cancel buttons
    $buttonPanel = New-Object Windows.Forms.Panel 
        $buttonPanel.Size = New-Object Drawing.Size @(400,40)
        $buttonPanel.Dock = "Bottom"
        $cancelButton = New-Object Windows.Forms.Button ; $cancelButton.Top = $buttonPanel.Height - $cancelButton.Height - 10; $cancelButton.Left = $buttonPanel.Width - $cancelButton.Width - 10
            $cancelButton.Text = "Cancel"
            $cancelButton.DialogResult = "Cancel"
            $cancelButton.Anchor = "Right"
        ## Create the Cancel button, which will anchor to the bottom right
        $cancelButton = New-Object Windows.Forms.Button ; $cancelButton.Top = $buttonPanel.Height - $cancelButton.Height - 10; $cancelButton.Left = $buttonPanel.Width - $cancelButton.Width - 10
            $cancelButton.Text = "Cancel"
            $cancelButton.DialogResult = "Cancel"
            $cancelButton.Anchor = "Right"
        ## Create the OK button, which will anchor to the left of Cancel
        $okButton = New-Object Windows.Forms.Button ; $okButton.Top = $cancelButton.Top ; $okButton.Left = $cancelButton.Left - $okButton.Width - 5
            $okButton.Text = "Ok"
            $okButton.DialogResult = "Ok"
            $okButton.Anchor = "Right"
        ## Create the Execute Checkbox, which will anchor to the bottom Left
        $ExecuteChk = New-Object Windows.Forms.checkbox ; $ExecuteChk.Width = 180; $ExecuteChk.Top = $buttonPanel.Height - $ExecuteChk.Height - 10; $ExecuteChk.Left = $buttonPanel.Width - $ExecuteChk.Width -10
            $ExecuteChk.Text = "Execute Now"
			$ExecuteChk.Checked = $ExecuteNow
            $cancelButton.Anchor = "Right"
        ## Add the buttons to the button panel
        ## Add the button panel to the form
        $buttonPanel.Controls.Add($okButton)
        $buttonPanel.Controls.Add($cancelButton)
        $buttonPanel.Controls.Add($ExecuteChk)
        $form.Controls.Add($buttonPanel)

    ## the actions for the buttons
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton
    $form.Add_Shown( { $form.Activate(); $txtUnique.Focus() } )
    Write-Host "Show form" (Get-Date)
    ## Show the form, and wait for the response
		$result = $form.ShowDialog()
		Write-Host " Result: $result" (Get-Date)
		## If they pressed OK (or Enter,) go through all the
		## checked items and send the corresponding object down the pipeline
		if($result -eq "OK")
		{   Write-Host "UniqueID" $txtUnique.Text -ForegroundColor Magenta
			Write-Host "SubName" $objListBox.SelectedItem -ForegroundColor Magenta 
			$ITCDC01Name = $txtCPU1.Text
			$ITCWFE01Name = $txtCPU2.Text
			$ITCSQL01Name = $txtCPU3.Text
			Write-Host "DC01 =" $ITCDC01Name -ForegroundColor Green 
			Write-Host "WFE01 =" $ITCWFE01Name -ForegroundColor Green 
			Write-Host "SQL01 =" $ITCSQL01Name -ForegroundColor Green
			$ITCLocation = $locListBox.SelectedItem
			Write-Host "Location set to" $ITCLocation -ForegroundColor Green
			$ITCNetworkName = $txtNetwork.Text.ToString() 
			$ITCNetConfig = $ITCNetworkName + ".config"
			Write-Host $ITCNetworkName 'will be used for creating network' -ForegroundColor Green 
			Write-Host $ITCNetConfig 'will be used for Network Configuration File' -ForegroundColor Green 
			$ITCUniqueID = $txtUnique.Text.ToString() 
			Write-Host $ITCUniqueID 'will be used for creating public names' -ForegroundColor Green 
			$adminusername = $txtUserName.Text
			$adminPassword = $txtPassword.Text
			Write-Host "User" $adminusername  -ForegroundColor Green 
			Write-Host "Pass" $adminPassword -ForegroundColor Green 
			$ExecuteNow = $ExecuteChk.Checked
			$ITCStoreName =  $txtStorage.Text.ToLower() + $ITCUniqueID.ToLower()     
			Write-Host $ITCStoreName 'will be used as the storage container' -ForegroundColor Green    
			$ITCServiceName = $txtService.Text + $ITCUniqueID 
			Write-Host $ITCServiceName 'will be used as the Cloud Service' -ForegroundColor Green    
			If (!(Test-AzureName -Name $ITCStoreName -Storage)) { 
				If (!(Test-AzureName -Name $ITCStoreName -Service)) { 
				} 
				Else {
				   write-host "Storage Account Name is not available. Please choose a different name!" -ForegroundColor Red
                   Return
				} 
			} 
			else {
				Write-host "Storage Account Name not valid: Storage account names must be between 3 and 24 characters in length and use numbers and lower-case letters only. It must also be unique in all of Azure storage" -foregroundcolor Red
				Return
			} 
		}
		Else {	Write-Host "User Cancelled" -ForegroundColor Red;  Return }   # User pressed cancel, just exit out
    
    
    $ITCSubName = $objListBox.SelectedItem.ToString() 	#What is the NAME of your subscription
    Write-Host $ITCSubName 'will be used as the default subscription' -ForegroundColor Green    
    $ITCDC01Image = $cbImage1.SelectedIndex
    $ITCWFE01Image = $cbImage2.SelectedIndex
    $ITCSQL01Image = $cbImage3.SelectedIndex

    Write-Host $ITCDC01Name  -ForegroundColor Magenta
    Write-Host "Default Image #" $ITCDC01Image  $ArrayImage[$ITCDC01Image].OS -ForegroundColor Magenta
    Write-Host "     " $ArrayImage[$ITCDC01Image].Label -ForegroundColor Green
    Write-Host "     " $ArrayImage[$ITCDC01Image].ImageName -ForegroundColor Green
    Write-Host $ArrayImage[$ITCDC01Image].Description -ForegroundColor Gray

    Write-Host $ITCWFE01Name  -ForegroundColor Magenta
    Write-Host "Default Image #" $ITCWFE01Image  $ArrayImage[$ITCWFE01Image].OS -ForegroundColor Magenta
    Write-Host "     " $ArrayImage[$ITCWFE01Image].Label -ForegroundColor Green
    Write-Host "     " $ArrayImage[$ITCWFE01Image].ImageName -ForegroundColor Green
    Write-Host $ArrayImage[$ITCWFE01Image].Description -ForegroundColor Gray

    Write-Host $ITCSQL01Name  -ForegroundColor Magenta
    Write-Host "Default Image #" $ITCSQL01Image  $ArrayImage[$ITCSQL01Image].OS -ForegroundColor Magenta
    Write-Host "     " $ArrayImage[$ITCSQL01Image].Label -ForegroundColor Green
    Write-Host "     " $ArrayImage[$ITCSQL01Image].ImageName -ForegroundColor Green
    Write-Host $ArrayImage[$ITCSQL01Image].Description -ForegroundColor Gray

#endregion Get-Variables From User
#region Create network Configuration File
Write-Host (Get-Date) -ForegroundColor Green
$WritePath = $ITCPath + $ITCNetConfig
Write-Host "Creating Network Configuration File" $WritePath -ForegroundColor Green
#if (Test-Path $path ) {Clear-Content  $path}   # Delete the existing file if it exists
$fileName = $ITCNetConfig
$fqName = (Get-Location).ToString() + "\"+$fileName
Write-Host "Creating Network Configuration File" $WritePath -ForegroundColor Green
$NetConfig = '<NetworkConfiguration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration">
  <VirtualNetworkConfiguration>
    <Dns>
      <DnsServers>
        <DnsServer name="'+$ITCDC01Name+'" IPAddress="10.100.11.5" />
      </DnsServers>
    </Dns>
    <VirtualNetworkSites>
      <VirtualNetworkSite name="'+$ITCNetworkName+'" Location="'+$ITCLocation+'">
        <AddressSpace>
          <AddressPrefix>10.100.0.0/16</AddressPrefix>
        </AddressSpace>
        <Subnets>
          <Subnet name="AD-Production">
            <AddressPrefix>10.100.0.0/24</AddressPrefix>
          </Subnet>
          <Subnet name="AD-Production-Static">
            <AddressPrefix>10.100.11.0/24</AddressPrefix>
          </Subnet>
        </Subnets>
      </VirtualNetworkSite>
    </VirtualNetworkSites>
  </VirtualNetworkConfiguration>
</NetworkConfiguration>'

$Filename
$SaveFile = $NetConfig
$fso = new-object -comobject scripting.filesystemobject
$file = $fso.CreateTextFile($fqName,$true)  #will overwrite any existing file 
$file.write($SaveFile)
$file.close()
#
Write-Host "Create Network ..." $NetworkName  -ForegroundColor Green 
Set-AzureVNetConfig -ConfigurationPath $fqName # Create or Modify a Network
#Note: this can also be used to modify a network too 
#
notepad $fqName  # Take a look at the resulting Network configuration File

#endregion Create Network Configuration File
#region create Cleanup Script
	Write-Host (Get-Date) -ForegroundColor Green
	$WritePath = $ITCPath + $ITCServiceName + "Cleanup.ps1"
	Write-Host "Creating Cleanup Script" $WritePath -ForegroundColor Green
	$CleanupScript = ''
	$CleanupScript += "`r`n`$ITCServiceName = '$ITCServiceName'"
	$CleanupScript += '
	Write-Host (Get-Date) -ForegroundColor Green
	Select-AzureSubscription -SubscriptionName  "' + $ITCSubName + '"
	$WebSitesToDelete = ""
	$VMsToDelete = "' + $ITCDC01Name + '", "' + $ITCSQL01Name + '", "' + $ITCWFE01Name + '"
	$StorageToDelete = "' + $ITCStoreName + '"
	if ($WebSitesToDelete -ne "" ) {Get-AzureWebsite | Where {$_.Name -in $websitesToDelete} | Remove-AzureWebsite -Force -Verbose}
	if ($VMsToDelete -ne "" ) {Get-AzureVM | Where {$_.Name -in $VMsToDelete} | Remove-AzureVM  -DeleteVHD -ServiceName "' + $ITCServiceName + '" -Verbose}
	Start-Sleep -Seconds 20
	Get-AzureDisk | Where {$_.AttachedTo -eq $null} | Remove-AzureDisk -DeleteVHD -Verbose
	Start-Sleep -Seconds 30
	Get-AzureDisk | Where {$_.AttachedTo -eq $null} | Remove-AzureDisk -DeleteVHD -Verbose
	Remove-AzureService -ServiceName "' + $ITCServiceName + '" -Force -Verbose
	# Often the disk takes longer to be released so we need to try again.  You may have to run the following command again later as Azure is often very delayed in allowing you to remove disks after you remove the machine.
	Get-AzureDisk | Where {$_.AttachedTo -eq $null} | Remove-AzureDisk -DeleteVHD -Verbose
	Start-Sleep -Seconds 30
	if ($StorageToDelete -ne "" ) {Get-AzureStorageAccount | Where {$_.Label -in $StorageToDelete} | Remove-AzureStorageAccount -Verbose}
	get-azureVNetConfig
	Write-Host "Network not removed.  Unremark the line in the script if you want it removed" -ForegroundColor Yellow
	Write-Host "CAUTION: it will remove ALL networks not just the lab network" -ForegroundColor Red
	#Remove-AzureVNetConfig -Verbose # This removes all Networks on the Subscription
	Write-Host (Get-Date) -ForegroundColor Green
	'
	$SaveFile = $CleanupScript
	$fso = new-object -comobject scripting.filesystemobject
	$file = $fso.CreateTextFile($WritePath,$true) 
	$file.write($SaveFile)
	$file.close()
	Notepad.exe $WritePath
#endregion Create Cleanup Script
#region Download Supporting Files

	Write-Host (Get-Date) -ForegroundColor Green
	$Username = ""
	$Password = ""
	$WebClient = New-Object System.Net.WebClient
	$WebClient.Credentials = New-Object System.Net.Networkcredential($Username, $Password)
	$Url = "https://itcmaster.blob.core.windows.net/fy15q3/ADProvisionScriptv2.ps1"
	$Path = $ITCPath + "ADProvisionScriptv2.ps1"
	Write-Host "Downloading..." $Path from $URL -ForegroundColor Green
	$WebClient.DownloadFile( $url, $path )
	$Url = "https://itcmaster.blob.core.windows.net/fy15q3/WebFEProvisionScript.ps1"
	$Path = $ITCPath + "WebFEProvisionScript.ps1"
	Write-Host "Downloading..." $Path from $URL -ForegroundColor Green
	$WebClient.DownloadFile( $url, $path )
	$Url = "https://itcmaster.blob.core.windows.net/fy15q3/SQLProvisionScript.ps1"
	$Path = $ITCPath + "SQLProvisionScript.ps1"
	Write-Host "Downloading..." $Path from $URL -ForegroundColor Green
	$WebClient.DownloadFile( $url, $path )
	#endregion Download Supporting Files
#endregion Pre-Lab Setup#region Build Execution Script & Build Infrastructure
#region Lab1
	Write-Host (Get-Date) -ForegroundColor Green
	$WritePath = $ITCPath + $ITCServiceName + "Build.ps1"
	Write-Host "Creating Build Script" $WritePath -ForegroundColor Green
	$BuildScript = "Write-Host (Get-Date) -ForegroundColor Green " 
	$BuildScript += "`r`n`$adminusername = '$adminusername'" 
	$BuildScript += "`r`n`$adminPassword = '$adminPassword'"
	$BuildScript += "`r`n`$ITCLocation = '$ITCLocation'"
	$BuildScript += "`r`n`$ITCSubName = '$ITCSubName'" 
	$BuildScript += "`r`n`$ITCStoreName = '$ITCStoreName'"
	$BuildScript += "`r`n`$ITCContainerName ='$ITCContainerName'"
	$BuildScript += "`r`n`$ITCPath = '$ITCPath'"
	$BuildScript += "`r`n`$ITCNetConfig ='$ITCNetConfig'"
	$BuildScript += "`r`n`$ITCNetConfigPath `= `$ITCPath `+ `$ITCNetConfig"
	$BuildScript += "`r`n`$ArrayImage = Get-AzureVMImage" 
	$BuildScript += "`r`n`$ITCServiceName = '$ITCServiceName'" 
	$BuildScript += "`r`n`$ITCDC01Name = '$ITCDC01Name'" 
	$BuildScript += "`r`n`$ITCWFE01Name = '$ITCWFE01Name'" 
	$BuildScript += "`r`n`$ITCSQL01Name = '$ITCSQL01Name'" 
	$BuildScript += "`r`n`$ITCDC01Image = '$ITCDC01Image'" 
	$BuildScript += "`r`n`$ITCWFE01Image = '$ITCWFE01Image'" 
	$BuildScript += "`r`n`$ITCSQL01Image = '$ITCSQL01Image'" 
	$BuildScript += "`r`n`$ITCNetworkName= '$ITCNetworkName'"

		#Lab 1  Create a virtual network, Storage, and CloudService
		Write-Host (Get-Date) -ForegroundColor Green
		Write-Host "Setting default Azure subscription to '$ITCSubName'"
		$BuildScript += "`r`n Set-AzureSubscription -SubscriptionName '$ITCSubName'"
		Set-AzureSubscription -SubscriptionName $ITCSubName
		##Create Storage Account
			Write-Host (Get-Date) -ForegroundColor Green
			Write-Host "Set Default Subscription ... '$ITCSubName'"  -ForegroundColor Green 
			Write-Host "Creating Storage Account... $ITCStoreName at $ITCLocation"  -ForegroundColor Green
			$BuildScript += "`r`n New-AzureStorageAccount -Location `$ITCLocation -StorageAccountName `$ITCStoreName -Type 'Standard_LRS'"

            if ($ExecuteNow) {New-AzureStorageAccount -Location $ITCLocation -StorageAccountName $ITCStoreName -Type "Standard_LRS"}
			Write-Host "Creating Container... " $ITCContainerName  -ForegroundColor Green 
			$BuildScript += "`r`n `$ITCStorageAccountKey = Get-AzureStorageKey `$ITCStoreName | %{ `$_.Primary }"
			if ($ExecuteNow) {$ITCStorageAccountKey = Get-AzureStorageKey $ITCStoreName | %{ $_.Primary }}
			$BuildScript += "`r`n `$ITCStoreContext = New-AzureStorageContext -StorageAccountName `$ITCStoreName -StorageAccountKey `$ITCStorageAccountKey"
			if ($ExecuteNow) {$ITCStoreContext = New-AzureStorageContext -StorageAccountName $ITCStoreName -StorageAccountKey $ITCStorageAccountKey}
			Write-Host "Set Default Store ..." $ITCStoreName  -ForegroundColor Green 
			$BuildScript += "`r`n Set-AzureSubscription –SubscriptionName '$ITCSubName' -CurrentStorageAccount $ITCStoreName"
			Set-AzureSubscription –SubscriptionName $ITCSubName -CurrentStorageAccount $ITCStoreName
			#creates the container in your storage account. I am not checking if container already exists.  # you can check by get-storagecontainer and check for errors.
			$BuildScript += "`r`n New-AzureStorageContainer `$ITCContainerName -Permission Container -Context `$ITCStoreContext"
			if ($ExecuteNow) {
                New-AzureStorageContainer $ITCContainerName -Permission Container -Context $ITCStoreContext
                }
            $BuildScript += "`r`n `$ITCStorageBlob = `$ITCStoreContext.BlobEndPoint"
			if ($ExecuteNow) {$ITCStorageBlob = $ITCStoreContext.BlobEndPoint}
			Write-Host "Uploading Scripts to Container... " $ITCContainerName  -ForegroundColor Green 
			if ($ExecuteNow) {
				$dir = $ITCPath
				# $_.mode -match "-a---" scans the data directory and only fetches the files. It filters out all directories
				$files = Get-ChildItem $dir -force| Where-Object {$_.mode -match "-a---"}
				# iterate through all the files and start uploading data
				foreach ($file in $files){
				 #fqName represents fully qualified name
				 $fqName = $dir + "\" + $file.Name	 #upload the current file to the blob add backslash in case it is needed
				 if ($file.Extension -ne ".publishsettings") {     # Exclude PublishSettings Files
					 Write-Host "Uploading " $dir $file.Name  -ForegroundColor Green 
					 Set-AzureStorageBlobContent -Blob $file.Name -Container $ITCContainerName -File $fqName -Context $ITCStoreContext -Force
				 }
				}
			}

			#$ITCNetConfigPath = $ITCStorageBlob + $ITCNetConfig
			$ITCNetConfigPath = $ITCPath + $ITCNetConfig
			$ITCNetConfigPath
		   # Write-Host "https://mystoreds.blob.core.windows.net/itc-files/ITC-VNet.config"
			Write-Host "Network Configuration Path set to" $ITCNetConfigPath -ForegroundColor Green
			Write-Host "Finished Uploading! " $ITCContainerName  -ForegroundColor Green 
		## Create network
			Write-Host (Get-Date) -ForegroundColor Green
			Write-Host "Create Network ..." $ITCNetworkName  -ForegroundColor Green 
			#Set-AzureVNetConfig -ConfigurationPath "<PATH>\azureNetworks.netcfg"
			$BuildScript += "`r`n Set-AzureVNetConfig -ConfigurationPath `$ITCNetConfigPath"
			if ($ExecuteNow) {Set-AzureVNetConfig -ConfigurationPath $ITCNetConfigPath}
			
		## Create Cloud Service
			Write-Host (Get-Date) -ForegroundColor Green
			Write-Host "Create Cloud Service ..." $ITCServiceName  -ForegroundColor Green 
			$BuildScript += "`r`n New-AzureService -Location `$ITCLocation -ServiceName `$ITCServiceName"
			if ($ExecuteNow) {New-AzureService -Location $ITCLocation -ServiceName $ITCServiceName}

	Write-Host "Finished Lab 1 Setup!"  -ForegroundColor Green 
	#endregion Lab1#region Lab2 Build Machines
#region Lab 2 Build Machines
	# $ITCImage = Get-AzureVMImage -ImageName "a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-201412.01-en.us-127GB.vhd"
	Write-Host (Get-Date) -ForegroundColor Green
	Write-Host "FYI - If you would like to see a list of images, run:" -ForegroundColor Gray
	Write-Host "Get-AzureVMImage | format-table Label, ImageName > CurrentImageList.txt"   -ForegroundColor Gray
	Write-Host "   then open the CurrentImageList.txt file created in the default directory" -ForegroundColor Gray 
	Write-Host "      use notepad++ or PowerShell ISE so you have line numbers" -ForegroundColor Gray

	#Wait 5 seconds  
	Start-Sleep -s 5  

	#DC01   #(Get-AzureVMImage)[163].ImageName 
		Write-Host (Get-Date) -ForegroundColor Green
		Write-Host "We will create all three machines and go back later to configure..." -ForegroundColor Green 
		Write-Host "Creating DC01 ... " $ITCDC01Name  "using"  ($ArrayImage[$ITCDC01Image].ImageName) -ForegroundColor Green 
		Write-Host "  Image... $ITCDC01Image " ($ArrayImage[$ITCDC01Image].label) -ForegroundColor Green 
		$BuildScript += "`r`n New-AzureVMConfig -Name `$ITCDC01Name -InstanceSize Small -ImageName `$ArrayImage[`$ITCDC01Image].ImageName.ToString() ``
		 | Add-AzureProvisioningConfig –Windows –Password `$adminPassword -AdminUsername `$adminusername ``
		 | Set-AzureSubnet 'AD-Production' ``
		 | New-AzureVM –ServiceName `$ITCServiceName -VNetName `$ITCNetworkName "
		if ($ExecuteNow) {New-AzureVMConfig -Name $ITCDC01Name -InstanceSize Small -ImageName $ArrayImage[$ITCDC01Image].ImageName.ToString() `
		 | Add-AzureProvisioningConfig –Windows –Password $adminPassword -AdminUsername $adminusername `
		 | Set-AzureSubnet "AD-Production" `
		 | New-AzureVM –ServiceName $ITCServiceName -VNetName $ITCNetworkName
		}
	#Wait 5 seconds  
	Start-Sleep -s 5  

	#WFE01	Create the Web server  # (Get-AzureVMImage)[$ImageArrayDefault].ImageName 
		Write-Host (Get-Date) -ForegroundColor Green
		Write-Host "Creating " $ITCWFE01Name "using"  ($ArrayImage[$ITCWFE01Image].ImageName) -ForegroundColor Green 
		Write-Host "  Image... $ITCWFE01Image " ($ArrayImage[$ITCWFE01Image].label) -ForegroundColor Green 
		$BuildScript += "`r`n New-AzureVMConfig -Name `$ITCWFE01Name -InstanceSize Small -ImageName `$ArrayImage[`$ITCWFE01Image].ImageName.ToString() ``
		 | Add-AzureProvisioningConfig –Windows –Password `$adminPassword -AdminUsername `$adminusername ``
		 | Set-AzureSubnet 'AD-Production' ``
		 | New-AzureVM –ServiceName `$ITCServiceName -VNetName `$ITCNetworkName"
		if ($ExecuteNow) {New-AzureVMConfig -Name $ITCWFE01Name -InstanceSize Small -ImageName $ArrayImage[$ITCWFE01Image].ImageName.ToString() `
		 | Add-AzureProvisioningConfig –Windows –Password $adminPassword -AdminUsername $adminusername `
		 | Set-AzureSubnet "AD-Production" `
		 | New-AzureVM –ServiceName $ITCServiceName -VNetName $ITCNetworkName
		}
	#Wait 5 seconds  
	Start-Sleep -s 5  

	#SQL01   (Get-AzureVMImage)[359].ImageName
		#$ITCImage = Get-AzureVMImage -ImageName "fb83b3509582419d99629ce476bcb5c8__SQL-Server-2014-RTM-12.0.2361.0-Enterprise-ENU-Win2012R2-cy14su05"
		Write-Host (Get-Date) -ForegroundColor Green
		Write-Host "Create " $ITCSQL01Name "using" $ArrayImage[$ITCSQL01Image].ImageName.ToString() -ForegroundColor Green 
		Write-Host "  Image... $ITCSQL01Image " $ArrayImage[$ITCSQL01Image].label -ForegroundColor Green 
		#SQL01	SQLImageName = "fb83b3509582419d99629ce476bcb5c8__SQL-Server-2014-RTM-12.0.2361.0-Enterprise-ENU-Win2012R2-cy14su05"
		#Get-AzureVMImage "fb83b3509582419d99629ce476bcb5c8__SQL-Server-2014-RTM-12.0.2361.0-Enterprise-ENU-Win2012R2-cy14su05"
		$BuildScript += "`r`n New-AzureVMConfig -Name `$ITCSQL01Name -InstanceSize Large -ImageName `$ArrayImage[`$ITCSQL01Image].ImageName.ToString() ``
		 | Add-AzureProvisioningConfig –Windows –Password `$adminPassword -AdminUsername `$adminusername ``
		 | Set-AzureSubnet 'AD-Production' ``
		 | New-AzureVM –ServiceName $ITCServiceName -VNetName $ITCNetworkName"
		if ($ExecuteNow) {New-AzureVMConfig -Name $ITCSQL01Name -InstanceSize Large -ImageName $ArrayImage[$ITCSQL01Image].ImageName.ToString() `
		 | Add-AzureProvisioningConfig –Windows –Password $adminPassword -AdminUsername $adminusername `
		 | Set-AzureSubnet "AD-Production" `
		 | New-AzureVM –ServiceName $ITCServiceName -VNetName $ITCNetworkName 
		}
#endregion Lab 2 Build Machines
#region Lab 2 post Configuration DC01
		##  Wait for machine to be running
		$BuildScript += "`r`n Write-Host 'Press Enter after " +$ITCDC01Name+" has a status of Running...'
		Pause"
		Write-Host (Get-Date) -ForegroundColor Green
			Write-Host "We need to make sure" $ITCDC01Name "is Running before continuing ..."   -ForegroundColor Green 
		if ($ExecuteNow) {
			$vm = Get-AzureVM –ServiceName $ITCServiceName -Name $ITCDC01Name
			$vmStatus = $vm.PowerState
			if (!($vm.PowerState -eq "Started")) {  
				do {  
					Write-host "Waiting for" $ITCDC01Name " to have a 'Started' status ...." $vmStatus   
					#Wait 5 seconds  
					Start-Sleep -s 5  
					#Check the power status  
					$vm = Get-AzureVM –ServiceName $ITCServiceName -Name $ITCDC01Name
					$vmStatus = $vm.PowerState  
				}until($vmStatus -eq "Started")  
				}
		}
		## Post Configuration
			Write-host $ITCDC01Name "is" $vmStatus   -ForegroundColor Green 
			Write-Host "Staring Post Configuration of ..." $ITCDC01Name  -ForegroundColor Green 
            # We need to change the IP address to static BEFORE upgrading to Domain Controller...
			Write-host "Configuring Static Network on " $ITCDC01Name  -ForegroundColor Green 
			#Set Static Microsoft Azure Networking Address
			$BuildScript += "`r`n Write-Host 'Configure Static Network' -ForegroundColor Green"
			$BuildScript += "`r`n #Get-AzureVM -Name `$ITCDC01Name -ServiceName `$ITCServiceName | Set-AzureSubnet -SubnetNames AD-Production-Static | Update-AzureVM 
			Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName 
			Test-AzureStaticVNetIP –VnetName $ITCNetworkName –IPAddress 10.100.11.5
			Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName | Set-AzureStaticVNetIP –IPAddress 192.168.11.5 | Update-AzureVM 
			Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName"
			if ($ExecuteNow) {
				Write-Host "Configure Static Network" -ForegroundColor Green
				Get-AzureVM -Name $ITCDC01Name -ServiceName $ITCServiceName | Set-AzureSubnet -SubnetNames AD-Production-Static | Update-AzureVM 
				#Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName
				#Let's Change the IP address 
				Test-AzureStaticVNetIP –VnetName $ITCNetworkName –IPAddress 10.100.11.5
				Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName | Set-AzureStaticVNetIP –IPAddress 10.100.11.5 | Update-AzureVM 
				#Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceN		
			}				

			#Lab2 DC01 Post Config
			#Before you run the next command to install the custom script extension and install AD, verify the version number of the extensions by running: 
			#Get-AzureVMAccessExtension |select ExtensionName, publisher, version.
			#verify if the extension is installed: 
			$BuildScript += "`r`n `$Vm = Get-AzureVM -ServiceName `$ITCServiceName -Name `$ITCDC01Name"
			if ($ExecuteNow) {
				$Vm = Get-AzureVM -ServiceName $ITCServiceName -Name $ITCDC01Name
				Get-AzureVMExtension -VM $Vm | Select ExtensionName, Publisher, Version 
			}
			Write-host "Enabling Azure Powershell Extension on" $ITCDC01Name  -ForegroundColor Green 
			#Install the extension  (this allows us to run PowerShell Scripts on the VM)
			$BuildScript += "`r`n Set-AzureVMExtension -ExtensionName CustomScriptExtension -VM `$vm -Publisher Microsoft.Compute -version 1.2 | Update-AzureVM -Verbose"
			if ($ExecuteNow) {Set-AzureVMExtension -ExtensionName CustomScriptExtension -VM $vm -Publisher Microsoft.Compute -version 1.2 | Update-AzureVM -Verbose}
			Write-Host "Azure Custom Script Handler Log can be found on the destination machine at: " -ForegroundColor Green
            Write-Host "     C:\WindowsAzure\Logs\Plugins"  -ForegroundColor Green
            Write-host "Custom Script output log can be found on the destination machine at:"  -ForegroundColor Green
            Write-Host "     C:\Temp\ProvisionLog.txt"  -ForegroundColor Green
            Write-host "The Script being executed is downloaded to:" -ForegroundColor Green
            Write-Host "     C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.2\Downloads" 
			Write-host "Running Configuration Script on" $ITCDC01Name  -ForegroundColor Green 
            Write-Host "     https://itcmaster.blob.core.windows.net/fy15q3/ADProvisionScriptv2.ps1" -ForegroundColor Green 
			# Run the post config powershell script on the DC01 VM
			$Arguments = '"ContosoAzure.com" "' + $adminpassword +'"' 
			$Arguments
            $BuildScript += "`r`n Set-AzureVMCustomScriptExtension -VM `$VM -FileUri 'https://itcmaster.blob.core.windows.net/fy15q3/ADProvisionScriptv2.ps1' -Run 'ADProvisionScriptv2.ps1'  | Update-AzureVM -Verbose"
			if ($ExecuteNow) {
                Set-AzureVMCustomScriptExtension `
                -VM $VM `
                -FileUri "https://itcmaster.blob.core.windows.net/fy15q3/ADProvisionScriptv2.ps1" `
                -Run "ADProvisionScriptv2.ps1" `
                -Argument $Arguments  `
                | Update-AzureVM -Verbose
            }
			Write-host "Configuring Static Network on " $ITCDC01Name  -ForegroundColor Green 
			#Set Static Microsoft Azure Networking Address
			$BuildScript += "`r`n Write-Host 'Configure Static Network' -ForegroundColor Green"
			$BuildScript += "`r`n #Get-AzureVM -Name `$ITCDC01Name -ServiceName `$ITCServiceName | Set-AzureSubnet -SubnetNames AD-Production-Static | Update-AzureVM 
			Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName 
			Test-AzureStaticVNetIP –VnetName $ITCNetworkName –IPAddress 10.100.11.5
			Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName | Set-AzureStaticVNetIP –IPAddress 192.168.11.5 | Update-AzureVM 
			Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName"
			if ($ExecuteNow) {
				Write-Host "Configure Static Network" -ForegroundColor Green
				Get-AzureVM -Name $ITCDC01Name -ServiceName $ITCServiceName | Set-AzureSubnet -SubnetNames AD-Production-Static | Update-AzureVM 
				#Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName
				#Let's Change the IP address 
				Test-AzureStaticVNetIP –VnetName $ITCNetworkName –IPAddress 10.100.11.5
				Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceName | Set-AzureStaticVNetIP –IPAddress 10.100.11.5 | Update-AzureVM 
				#Get-AzureVM -Name $ITCDC01Name –ServiceName $ITCServiceN		
			}				
			Write-host "Finished configuring" $ITCDC01Name  -ForegroundColor Green 
#endregion End Lab2 DC01 Post Config
#region Lab2 SQL01 Post Configuration
		$BuildScript += "`r`n Write-Host 'Press Enter after " +$ITCSQL01Name+" has a status of Running... '`r`n	Pause"
		#  Wait for machine to be running
			Write-Host (Get-Date) -ForegroundColor Green
			Write-Host "We need to make sure" $ITCSQL01Name "is RUNNING before continuing ..."   -ForegroundColor Green 
			if ($ExecuteNow) {
				$vm = Get-AzureVM –ServiceName $ITCServiceName -Name $ITCSQL01Name
				$vmStatus = $vm.PowerState
				if (!($vm.PowerState -eq "Started")) {  
					do {  
						Write-host "Waiting for" $ITCSQL01Name " to have a 'Started' status ...." $vmStatus   
						#Wait 5 seconds  
						Start-Sleep -s 5  
						#Check the power status  
						$vm = Get-AzureVM –ServiceName $ITCServiceName -Name $ITCSQL01Name
						$vmStatus = $vm.PowerState  
					}until($vmStatus -eq "Started")  
					}  
				Write-host $ITCSQL01Name "is" $vmStatus   -ForegroundColor Green 
			}
		# SQL01 Post Config
			Write-Host (Get-Date) -ForegroundColor Green
			Write-Host "Starting Post Configuration of ..." $ITCSQL01Name  -ForegroundColor Green 
			#Add Additional Disk to SQL01
			Write-Host "Adding Data Disk to" $ITCSQL01Name  -ForegroundColor Green 
			$BuildScript += "`r`n Get-AzureVM `$ITCServiceName -Name `$ITCSQL01Name | Add-AzureDataDisk -CreateNew -DiskSizeInGB 128 -DiskLabel 'SQLData' -LUN 0  | Update-AzureVM"
			if ($ExecuteNow) {
			  Get-AzureVM $ITCServiceName -Name $ITCSQL01Name `
			  | Add-AzureDataDisk -CreateNew -DiskSizeInGB 128 -DiskLabel "SQLData" -LUN 0 `
			  | Update-AzureVM
			}  
			Write-host "Enabling Azure Powershell Extension on" $ITCSQL01Name  -ForegroundColor Green 
			#verify if the extension is installed:   #Get-AzureVMAccessExtension |select ExtensionName, publisher, version.
			$BuildScript += "`r`n `$Vm = Get-AzureVM -ServiceName `$ITCServiceName -Name `$ITCSQL01Name"
			$Vm = Get-AzureVM -ServiceName $ITCServiceName -Name $ITCSQL01Name
			if ($ExecuteNow) {
				Get-AzureVMExtension -VM $Vm | Select ExtensionName, Publisher, Version 
			}
			#Install the extension  (this allows us to run PowerShell Scripts on the VM)
			$BuildScript += "`r`n Set-AzureVMExtension -ExtensionName CustomScriptExtension -VM `$vm -Publisher Microsoft.Compute -version 1.2 | Update-AzureVM -Verbose"
			if ($ExecuteNow) {Set-AzureVMExtension -ExtensionName CustomScriptExtension -VM $vm -Publisher Microsoft.Compute -version 1.2 | Update-AzureVM -Verbose}
			Write-Host "Azure Custom Script Handler Log can be found on the destination machine at: " -ForegroundColor Green
            Write-Host "     C:\WindowsAzure\Logs\Plugins"  -ForegroundColor Green
            Write-host "Custom Script output log can be found on the destination machine at:"  -ForegroundColor Green
            Write-Host "     C:\Temp\ProvisionLog.txt"  -ForegroundColor Green
            Write-host "The Script being executed is downloaded to:" -ForegroundColor Green
            Write-Host "     C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.2\Downloads" 
			Write-host "Running Configuration Script on " $ITCSQL01Name  -ForegroundColor Green 
			Write-host "    https://itcmaster.blob.core.windows.net/fy15q3/SQLProvisionScript.ps1"  -ForegroundColor Green 
			# Run the post config powershell script on the SQL01 VM
			$Arguments = '"'+$adminusername+'" "' + $adminpassword +'"' 
			$Arguments
			$Arguments = "$adminusername $adminpassword"
			$BuildScript += "`r`n Set-AzureVMCustomScriptExtension -VM `$VM -FileUri 'https://itcmaster.blob.core.windows.net/fy15q3/SQLProvisionScript.ps1' -Run 'SQLProvisionScript.ps1'  | Update-AzureVM -Verbose"
			if ($ExecuteNow) {
                Set-AzureVMCustomScriptExtension -VM $VM -FileUri "https://itcmaster.blob.core.windows.net/fy15q3/SQLProvisionScript.ps1" `
                -Run 'SQLProvisionScript.ps1'  `
                -Argument $Arguments   `
                | Update-AzureVM -Verbose}
			Write-host "Configuration started on" $ITCSQL01Name "Scripts could take an additional 15 mins or more to complete." -ForegroundColor Green 
#endregion Lab2 SQL01 Post Config
#region Lab 2 post Configuration WFE01
		##  Wait for machine to be running
		$BuildScript += "`r`n Write-Host 'Press Enter after " +$ITCWFE01Name+" has a status of Running...'
		Pause"
		Write-Host (Get-Date) -ForegroundColor Green
			Write-Host "We need to make sure" $ITCWFE01Name "is Running before continuing ..."   -ForegroundColor Green 
		if ($ExecuteNow) {
			$vm = Get-AzureVM –ServiceName $ITCServiceName -Name $ITCWFE01Name
			$vmStatus = $vm.PowerState
			if (!($vm.PowerState -eq "Started")) {  
				do {  
					Write-host "Waiting for" $ITCWFE01Name " to have a 'Started' status ...." $vmStatus   
					#Wait 5 seconds  
					Start-Sleep -s 5  
					#Check the power status  
					$vm = Get-AzureVM –ServiceName $ITCServiceName -Name $ITCWFE01Name
					$vmStatus = $vm.PowerState  
				}until($vmStatus -eq "Started")  
				}
		}
		## Post Configuration
			Write-host $ITCWFE01Name "is" $vmStatus   -ForegroundColor Green 
			Write-Host "Staring Post Configuration of ..." $ITCWFE01Name  -ForegroundColor Green 
			#Lab2 WEbFE01 Post Config
			#verify if the extension is installed: 
			$BuildScript += "`r`n `$Vm = Get-AzureVM -ServiceName `$ITCServiceName -Name `$ITCWFE01Name"
			$Vm = Get-AzureVM -ServiceName $ITCServiceName -Name $ITCWFE01Name
			if ($ExecuteNow) {
				Get-AzureVMExtension -VM $Vm | Select ExtensionName, Publisher, Version 
			}
			Write-host "Enabling Azure Powershell Extension on" $ITCWFE01Name  -ForegroundColor Green 
			#Install the extension  (this allows us to run PowerShell Scripts on the VM)
			$BuildScript += "`r`n Set-AzureVMExtension -ExtensionName CustomScriptExtension -VM `$vm -Publisher Microsoft.Compute -version 1.2 | Update-AzureVM -Verbose"
			if ($ExecuteNow) {
                #Remove-AzureVMExtension -ExtensionName CustomScriptExtension -VM $vm -Publisher Microsoft.Compute | Update-AzureVM -Verbose
                Set-AzureVMExtension -ExtensionName CustomScriptExtension -VM $vm -Publisher Microsoft.Compute -version 1.2 | Update-AzureVM -Verbose
            }
            $BuildScript += "`r`n Set-AzureVMCustomScriptExtension -VM `$VM -FileUri 'https://itcmaster.blob.core.windows.net/fy15q3/WebFEProvisionScript.ps1' -Run 'WebFEProvisionScript.ps1'  | Update-AzureVM -Verbose"
			Write-Host "Azure Custom Script Handler Log can be found on the destination machine at: " -ForegroundColor Green
            Write-Host "     C:\WindowsAzure\Logs\Plugins"  -ForegroundColor Green
            Write-host "Custom Script output log can be found on the destination machine at:"  -ForegroundColor Green
            Write-Host "     C:\Temp\ProvisionLog.txt"  -ForegroundColor Green
            Write-host "The Script being executed is downloaded to:" -ForegroundColor Green
            Write-Host "     C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.2\Downloads" 
			Write-host "Running Configuration Script on " $ITCWFE01Name  -ForegroundColor Green 
			Write-host "     https://itcmaster.blob.core.windows.net/fy15q3/WebFEProvisionScript.ps1"   -ForegroundColor Green 
			$Arguments = '"'+$adminusername+'" "' + $adminpassword +'"' 
			$Arguments
			if ($ExecuteNow) {
                Set-AzureVMCustomScriptExtension `
                -VM $VM `
                -FileUri "https://itcmaster.blob.core.windows.net/fy15q3/WebFEProvisionScript.ps1" `
                -Run 'WebFEProvisionScript.ps1'  `
                -Argument $Arguments `
                |  Update-AzureVM -Verbose
             }
			Write-host "Opening Endpoints on " $ITCWFE01Name  -ForegroundColor Green 
			#Set Static Microsoft Azure Networking Address
			$BuildScript += "`r`n Get-AzureVM -Name `$ITCWFE01Name -ServiceName `$ITCServiceName | Add-AzureEndpoint -Name 'HttpIn' -Protocol 'tcp' -PublicPort 80 -LocalPort 80 | Update-AzureVM"
			$BuildScript += "`r`n Get-AzureVM -Name `$ITCWFE01Name -ServiceName `$ITCServiceName | Add-AzureEndpoint -Name 'HttpsIn' -Protocol 'tcp' -PublicPort 443 -LocalPort 443 | Update-AzureVM"
			$BuildScript += "`r`n Get-AzureVM -Name `$ITCWFE01Name -ServiceName `$ITCServiceName | Add-AzureEndpoint -Name 'Custom5000' -Protocol 'tcp' -PublicPort 5000 -LocalPort 5000 | Update-AzureVM"
			$BuildScript += "`r`n Get-AzureVM -Name `$ITCWFE01Name -ServiceName `$ITCServiceName | Add-AzureEndpoint -Name 'Custom5001' -Protocol 'tcp' -PublicPort 5001 -LocalPort 5001 | Update-AzureVM"
			if ($ExecuteNow) {
				Get-AzureVM -Name $ITCWFE01Name -ServiceName $ITCServiceName | Add-AzureEndpoint -Name 'HttpIn' -Protocol 'tcp' -PublicPort 80 -LocalPort 80 | Update-AzureVM
				Get-AzureVM -Name $ITCWFE01Name -ServiceName $ITCServiceName | Add-AzureEndpoint -Name 'HttpsIn' -Protocol 'tcp' -PublicPort 443 -LocalPort 443 | Update-AzureVM
				Get-AzureVM -Name $ITCWFE01Name -ServiceName $ITCServiceName | Add-AzureEndpoint -Name 'Custom5000' -Protocol 'tcp' -PublicPort 5000 -LocalPort 5000 | Update-AzureVM
				Get-AzureVM -Name $ITCWFE01Name -ServiceName $ITCServiceName | Add-AzureEndpoint -Name 'Custom5001' -Protocol 'tcp' -PublicPort 5001 -LocalPort 5001 | Update-AzureVM
				}				
			Write-host "Finished configuring" $ITCWFE01Name  -ForegroundColor Green 
#endregion End Lab2 WEBFE01 Post Config
$SaveFile = $BuildScript
$fso = new-object -comobject scripting.filesystemobject
$file = $fso.CreateTextFile($WritePath,$true) 
$file.write($SaveFile)
$file.close()
Notepad.exe $WritePath

Write-Host "NOTE: Set DNS server on ITC-VNET ... Use the GUI  :-)" -ForegroundColor Red

#endregion Lab2

#region Lab3 
#Lab 3 Work with identity
#First install the Microsoft Online Services Sign-In Assistant for IT Professionals RTW (64-bit): http://go.microsoft.com/fwlink/?LinkID=286152  
#You will need these cmdlets (64bit cmdlets)  http://go.microsoft.com/fwlink/p/?linkid=236297
#Add-AzureAccount
#$msolcred = get-credential
#connect-msolservice
#endregion Lab3

If (!$ExecuteNow) {
  Write-Host "WARNING: Execute Now Turned Off! " -NoNewline -ForegroundColor Red 
  Write-Host "Scripts were built but not executed! " $WritePath -ForegroundColor Yellow
  Write-Host "Script Location:" $WritePath -ForegroundColor Green
  }
Write-Host "Started at: " $StartTime -ForegroundColor Green
Write-Host "Finished at: " (Get-Date) -ForegroundColor Green
