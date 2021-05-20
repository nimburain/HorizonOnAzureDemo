#this will be our temp folder - need it for download / logging
$tmpDir = "c:\temp\" 

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force }

#write a log file with the same name of the script
Start-Transcript "$tmpDir\$($SCRIPT:MyInvocation.MyCommand).log"

#To install AD we need PS support for AD first
$features = @("FileAndStorage-Services", "File-Services", "FS-FileServer", "FS-Data-Deduplication", "Storage-Services", "RSAT-AD-Tools", "RSAT-AD-AdminCenter", "RSAT-ADDS-Tools", "RSAT-AD-PowerShell", "RSAT-ADDS", "RSAT-ADLDS", "RSAT-AD-Tools"    )
Install-WindowsFeature -Name $features -Verbose 

#Download some tools. e.g. for benchmarking storage IO
$Downloads = @( "https://vorboss.dl.sourceforge.net/project/iometer/iometer-stable/1.1.0/iometer-1.1.0-win64.x86_64-bin.zip")

foreach ($download in $Downloads) {
    $downloadPath = $tmpDir + "\$(Split-Path $download -Leaf)"
    if (!(Test-Path $downloadPath )) { #download if not there
        $bitsJob = start-bitstransfer "$download" "$downloadPath" -Priority High -RetryInterval 60 -Verbose -TransferType Download #wait until downloaded.
        Get-BitsTransfer -Verbose -AllUsers
    }
}

# Set Timezone to West Europe Std Time
Set-TimeZone -Id "W. Europe Standard Time"

# Setup external NTP Services
w32tm /config /syncfromflags:manual /manualpeerlist:"demo-dc01.demo.local"
w32tm /config /reliable:yes
w32tm /config /update

#disable IE Enhanced Security Configuration
$ieESCAdminPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$ieESCUserPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
$ieESCAdminEnabled = (Get-ItemProperty -Path $ieESCAdminPath).IsInstalled
$ieESCAdminEnabled = 0
Set-ItemProperty -Path $ieESCAdminPath -Name IsInstalled -Value $ieESCAdminEnabled
Set-ItemProperty -Path $ieESCUserPath -Name IsInstalled -Value $ieESCAdminEnabled

#Do we find Data disks (raw by default) in this VM? 
$RawDisks = Get-Disk | where PartitionStyle -eq "RAW"

$driveLetters = ("f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z")

$i = 0
foreach ($RawDisk in $RawDisks) {
    $currentDriveLetter = $driveLetters[$i]

    New-Volume -DiskNumber $RawDisk.Number -FriendlyName "Data$i" -FileSystem NTFS -DriveLetter $currentDriveLetter
    $myDir = "$($currentDriveLetter):\Profiles"
    mkdir $myDir
    # Create folder MD X:\VMS # Create file share 
    New-SmbShare -Name "Profiles$i" -Path "$myDir" -FullAccess "Everyone"
    # Set NTFS permissions from the file share permissions 
    #(Get-SmbShare "Profiles0").PresetPathAcl | Set-Acl 

    $userDomain = (Get-Item Env:\USERDOMAIN).value

    $users = @("$userDomain\Domain Admins", "$userDomain\Horizon View Users")
    foreach ($user in $users) {
        $acl = get-acl -path $myDir
        $new = $user, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $new
        $acl.AddAccessRule($accessRule)
        $acl | Set-Acl $myDir
    }

    for ($i = 1; $i -le 5; $i++) { 
        $aduser = Get-ADUser -Filter "Name -like ""test$i"""
        $userProfilePath = "$myDir\$($aduser.SID)_test$i"
        mkdir $userProfilePath
        $users = @("$userDomain\Domain Admins", "$userDomain\$($aduser.Name)")
        $acl = get-acl -path $userProfilePath
        $acl.SetAccessRuleProtection($true, $false)
        $acl | Set-Acl
        foreach ($user in $users) {
            $new = $user, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $new
            $acl.AddAccessRule($accessRule)
            $acl | Set-Acl $userProfilePath
        }
    }

    $i++
}
<#
# Report that you have installed the fileserver - this code will only trigger a website to raise a counter++ - i.e. no private data (e.g. ipaddresses will be transmitted)
$apiURL = "https://bfrankpageviewcounter.azurewebsites.net/api/GetPageViewCount"
$body = @{URL='wvdsdbox-fileserver'} | ConvertTo-Json
Invoke-WebRequest -Method Post -Uri $apiURL -Body $body -ContentType 'application/json'
#>
stop-transcript
