$serviceName = "MyService"

if (Get-Service $serviceName -ErrorAction SilentlyContinue)
{
    $serviceToRemove = Get-WmiObject -Class Win32_Service -Filter "name='$serviceName'"
    $serviceToRemove.delete()
    "Service Removed"
}
else
{
    "Service Not Present"
}

"Installing Service"

$secpasswd = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential (".\MYUser", $secpasswd)
$binaryPath = "c:\servicebinaries\test-service.ps1"
Copy-Item "$PSScriptRoot\test-service.ps1" $binaryPath -Force
New-Service -name $serviceName -binaryPathName $binaryPath -displayName $serviceName -startupType Automatic -credential $mycreds

"Installation Completed"