#########################
# Domaincontroller
#########################
#
# These are some parameters for the dc deployment
$credential = Get-Credential -Message "Your VM Admin" -UserName 'demoadmin'
$templateParameterObject1 = @{
'vmName' =  [string] 'DEMO-DC01'
'adminUser'= [string] $($credential.UserName)
'adminPassword' = [securestring]$($credential.Password)
'vmSize'=[string] 'Standard_F2s'
'DiskSku' = [string] 'StandardSSD_LRS'
'DomainName' = [string] 'demo.local'
}

$deploymentstart = Get-Date

#Deploy the network
New-AzResourceGroupDeployment -ResourceGroupName 'rg-demo-basics' -Name 'NetworkSetup' -Mode Incremental -TemplateUri 'https://raw.githubusercontent.com/nimburain/scripts/main/01-ARM_Network.json'

#Deploy the VM and make it a domain controller
New-AzResourceGroupDeployment -ResourceGroupName 'rg-demo-basics' -Name 'DCSetup' -Mode Incremental -TemplateUri 'https://raw.githubusercontent.com/nimburain/scripts/main/02-ARM_AD.json' -TemplateParameterObject $templateParameterObject1

#make sure DC is new DNS server in this VNET  
az network vnet update -g 'rg-demo-basics' -n 'SDBOX-VNET' --dns-servers 10.0.0.4 

#Restart the DC
Restart-AzVM -Name $($templateParameterObject1.vmName) -ResourceGroupName 'rg-demo-basics'

#wait for domain services to come online they may take a while to start up so query the service from within the vm.
$tempFile = "AzVMRunCommand"+ $("{0:D4}" -f (Get-Random -Maximum 9999))+".tmp.ps1"

$code = @"
    if (`$(Get-Service ADWS).Status -eq 'Running'){
    "ADWS is Running"
    }
"@
$code | Out-File $tempFile    #write this Powershell code into a local file 

do
{
    $result = Invoke-AzVMRunCommand -ResourceGroupName 'rg-demo-basics' -Name $($templateParameterObject1.vmName)  -CommandId 'RunPowerShellScript' -ScriptPath $tempFile
    Start-Sleep -Seconds 30
}
until ($result.Value.Message -contains "ADWS is Running")

#########################
# Fileserver / Jumphost
#########################
#
# These are some parameters for the File Server deployment
$templateParameterObject2 = @{
'vmName' =  [string] 'DEMO-FS01'
'adminUser'= [string] $($credential.UserName)
'adminPassword' = [securestring]$($credential.Password)
'vmSize'=[string] 'Standard_F2s'
'DiskSku' = [string] 'StandardSSD_LRS'
'DomainName' = [string] 'demo.local'
}
New-AzResourceGroupDeployment -ResourceGroupName 'rg-demo-basics' -Name 'FileServerSetup' -Mode Incremental -TemplateUri 'https://raw.githubusercontent.com/nimburain/scripts/main/03-ARM_FS.json' -TemplateParameterObject $templateParameterObject2

#cleanup: remove 'DCInstall' extension
Remove-AzVMCustomScriptExtension -Name 'DCInstall' -VMName $($templateParameterObject1.vmName) -ResourceGroupName 'rg-demo-basics' -Force  

#Do post AD installation steps: e.g. create OUs and some Horizon View Demo Users.
Set-AzVMCustomScriptExtension -Name 'PostDCActions' -VMName $($templateParameterObject1.vmName) -ResourceGroupName 'rg-demo-basics' -Location (Get-AzVM -ResourceGroupName 'rg-demo-basics' -Name $($templateParameterObject1.vmName)).Location -Run 'CSE_AD_Post.ps1' -Argument "HorizonView $($credential.GetNetworkCredential().Password)" -FileUri 'https://raw.githubusercontent.com/nimburain/scripts/main/CSE_AD_Post.ps1'  
  
#Cleanup
Remove-AzVMCustomScriptExtension -Name 'PostDCActions' -VMName $($templateParameterObject1.vmName) -ResourceGroupName 'rg-demo-basics' -Force -NoWait

# make this server a file server.
Set-AzVMCustomScriptExtension -Name 'FileServerInstall' -VMName $($templateParameterObject2.vmName) -ResourceGroupName 'rg-demo-basics' -Location (Get-AzVM -ResourceGroupName 'rg-demo-basics' -Name $($templateParameterObject2.vmName)).Location -Run 'CSE_FS.ps1' -FileUri 'https://raw.githubusercontent.com/nimburain/scripts/main/CSE_FS.ps1' 

#Cleanup
Remove-AzVMCustomScriptExtension -Name 'FileServerInstall' -VMName $($templateParameterObject2.vmName) -ResourceGroupName 'rg-demo-basics' -Force -NoWait  
  
#done :-)
"Hey you are done - your deployment took:{0}" -f  $(NEW-TIMESPAN –Start $deploymentstart –End $(Get-Date)).ToString("hh\:mm\:ss") 