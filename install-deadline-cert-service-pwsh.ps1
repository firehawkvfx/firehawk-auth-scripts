$ErrorActionPreference = "Stop"
$serviceName = "MyService"

if (Get-Service $serviceName -ErrorAction SilentlyContinue)
{
    $serviceToRemove = Get-CimInstance -Class Win32_Service -Filter "name='$serviceName'"
    $serviceToRemove | Remove-CimInstance
    "Service Removed"
}
else
{
    "Service Not Present"
}

"Installing Service"

$secpasswd = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential (".\user", $secpasswd)

if (-Not (Test-Path -Path "c:\AppData" -PathType Container)) {
    New-Item "c:\AppData" -ItemType Directory
}

$binaryPath = "c:\AppData\test-service.ps1"
Copy-Item "$PSScriptRoot\test-service.ps1" $binaryPath -Force
New-Service -name $serviceName -binaryPathName $binaryPath -displayName $serviceName -startupType Automatic -credential $mycreds

"Installation Completed"