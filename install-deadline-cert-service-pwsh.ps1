# See:
# https://www.reddit.com/r/PowerShell/comments/jymq50/creating_a_windows_service_to_run_script_every/
# https://github.com/winsw/winsw/discussions/864
# https://github.com/winsw/winsw/blob/v3/docs/xml-config-file.md

$appDir = "c:\AppData"
$servicePath = "$appDir\myservice.exe"
$pwshPath = "$appDir\myservice.ps1"

$ErrorActionPreference = "Stop"
$serviceName = "MyService"
$myDownloadUrl="https://github.com/winsw/winsw/releases/download/v3.0.0-alpha.10/WinSW-x64.exe"

if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
    $serviceToRemove = Get-CimInstance -Class Win32_Service -Filter "name='$serviceName'"
    $serviceToRemove | Remove-CimInstance
    Remove-Item -Path $appdir\* -Include myservice*
    "Service Removed"
}
else {
    "Service Not Present"
}

"Installing Service"

# $secpasswd = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
# $mycreds = New-Object System.Management.Automation.PSCredential (".\$env:UserName", $secpasswd)

# $batPath = "$appDir\myservice.bat"

if (-Not (Test-Path -Path "$appDir" -PathType Container)) {
    New-Item "$appDir" -ItemType Directory
}

Copy-Item "$PSScriptRoot\pwsh-service\myservice.ps1" $appDir -Force
Copy-Item "$PSScriptRoot\pwsh-service\myservice.bat" $appDir -Force
Copy-Item "$PSScriptRoot\pwsh-service\myservice.xml" $appDir -Force
# New-Service -name $serviceName -binaryPathName $pwshPath -displayName $serviceName -startupType Automatic 
# -credential $mycreds


Invoke-WebRequest $myDownloadUrl -OutFile $servicePath
powershell -ExecutionPolicy Bypass -File $pwshPath
& "$servicePath" install
powershell -ExecutionPolicy Bypass -File $pwshPath
# & "$servicePath" start
# & "$servicePath" status

"Installation Completed"