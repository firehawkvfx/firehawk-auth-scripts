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

# powershell -Command "Start-Process 'C:\Windows\SysWOW64\cmd.exe' -Verb RunAs -ArgumentList 'powershell Set-ExecutionPolicy RemoteSigned'"
# powershell -Command "Start-Process 'C:\Windows\system32\cmd.exe' -Verb RunAs -ArgumentList 'powershell Set-ExecutionPolicy RemoteSigned'"
Write-Host '1) Ensure you have opened:
C:\Windows\SysWOW64\cmd.exe
2) run:
powershell Set-ExecutionPolicy RemoteSigned
3) Next open:
C:\Windows\system32\cmd.exe 
4) and run:
powershell Set-ExecutionPolicy RemoteSigned
5) Then you can run this script in a powershell 7 shell (with 
admin priviledges) to install the service.
'

$answer = Read-Host -Prompt 'Have you followed the above steps? [Y/n]'
if (-Not ("$answer".ToLower() -eq 'y')) {
    Write-Host "Exiting"
    exit
}

if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
    # $serviceToRemove = Get-CimInstance -Class Win32_Service -Filter "name='$serviceName'"
    # $serviceToRemove | Remove-CimInstance
    & "$servicePath" stop
    & "$servicePath" uninstall
    Remove-Item -Path $appdir\* -Include myservice*
    "Service Removed"
}
else {
    "Service Not Present"
}

"Ensure dir exists"
if (-Not (Test-Path -Path "$appDir" -PathType Container)) {
    New-Item "$appDir" -ItemType Directory
}
"Copy service to target location"
Copy-Item "$PSScriptRoot\pwsh-service\myservice.ps1" $appDir -Force
Copy-Item "$PSScriptRoot\pwsh-service\myservice.xml" $appDir -Force
# bash processes
Copy-Item "$PSScriptRoot\aws-auth-deadline-cert" $appDir -Force
Copy-Item "$PSScriptRoot\get-vault-file" $appDir -Force

"Download winsw"
Invoke-WebRequest $myDownloadUrl -OutFile $servicePath
"Installing service"
& "$servicePath" install
"Start service"
& "$servicePath" start
"Service Status"
& "$servicePath" status

"Installation Completed"