<#
Configure AD Permissions for Service Account to Join Computers to a specific OU
If u want to give Access to "OU=HorizonView,DC=demo,DC=local", just type "OU=HorizonView"
Example: 
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
    Set-Location C:\Setup\Scripts
    .\Set-OUPermissions.ps1 -Account svc1 -TargetOU "OU=HorizonView"
#>

Param
(
[parameter(mandatory=$true,HelpMessage="Please, provide a name.")][ValidateNotNullOrEmpty()]$Account,
[parameter(mandatory=$true,HelpMessage="Please, provide the organization unit to be used.")][ValidateNotNullOrEmpty()]$TargetOU
)

# Start logging to screen
Write-host (get-date -Format u)" - Starting"

# This i what we typed in
Write-host "Account to search for is" $Account
Write-Host "OU to search for is" $TargetOU

$CurrentDomain = Get-ADDomain

$OrganizationalUnitDN = $TargetOU+","+$CurrentDomain
$SearchAccount = Get-ADUser $Account

$SAM = $SearchAccount.SamAccountName
$UserAccount = $CurrentDomain.NetBIOSName+"\"+$SAM

Write-Host "Account is = $UserAccount"
Write-host "OU is =" $OrganizationalUnitDN

dsacls.exe $OrganizationalUnitDN /G $UserAccount":CCDC;Computer" /I:T | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":LC;;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":RC;;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":WD;;Computer" /I:S  | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":WP;;Computer" /I:S  | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":RP;;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":CA;Reset Password;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":CA;Change Password;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":WS;Validated write to service principal name;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN /G $UserAccount":WS;Validated write to DNS host name;Computer" /I:S | Out-Null
dsacls.exe $OrganizationalUnitDN