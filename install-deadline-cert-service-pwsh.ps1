# See:
# https://www.reddit.com/r/PowerShell/comments/jymq50/creating_a_windows_service_to_run_script_every/
# https://github.com/winsw/winsw/discussions/864
# https://github.com/winsw/winsw/blob/v3/docs/xml-config-file.md

$ErrorActionPreference = "Stop"
$serviceName = "MyService"
$myDownloadUrl="https://github.com/winsw/winsw/releases/download/v3.0.0-alpha.10/WinSW-x64.exe"

if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
    $serviceToRemove = Get-CimInstance -Class Win32_Service -Filter "name='$serviceName'"
    $serviceToRemove | Remove-CimInstance
    "Service Removed"
}
else {
    "Service Not Present"
}

"Installing Service"

# $secpasswd = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
# $mycreds = New-Object System.Management.Automation.PSCredential (".\$env:UserName", $secpasswd)

if (-Not (Test-Path -Path "c:\AppData" -PathType Container)) {
    New-Item "c:\AppData" -ItemType Directory
}

$servicePath = "c:\AppData\myservice.exe"
$binaryPath = "c:\AppData\myservice.ps1"
Copy-Item "$PSScriptRoot\myservice.ps1" $binaryPath -Force
Copy-Item "$PSScriptRoot\myservice.xml" "c:\AppData\myservice.xml" -Force
# New-Service -name $serviceName -binaryPathName $binaryPath -displayName $serviceName -startupType Automatic 
# -credential $mycreds


Invoke-WebRequest $myDownloadUrl -OutFile $servicePath
powershell -ExecutionPolicy Bypass -File $binaryPath
& "$servicePath" install
& "$servicePath" start
& "$servicePath" status

"Installation Completed"