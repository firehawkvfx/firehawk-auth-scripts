#Requires -Version 7.0

<#
  .SYNOPSIS
  Installs the automatic deadline cert service for conection with Vault in Firehawk

  .DESCRIPTION
  A windows service that will poll for new powershell certificates.

  To aquire AWS credentials, run the following from the provisioner ec2 instance:
  sudo su - ec2-user
  cd server
  source ./update_vars.sh
  deploy/firehawk-main/modules/terraform-aws-vpn/modules/openvpn-vagrant-client/scripts/firehawk-auth-scripts/sign-ssh-key --generate-aws-key

  .PARAMETER deadline_user_name
  Specifies the user name that will be used to determine the home dir to place the deadline certificate.

  .INPUTS
  None. You cannot pipe objects to this script.

  .OUTPUTS
  None.

  .EXAMPLE
  PS> .\install-deadline-cert-service-pwsh.ps1 -resourcetier dev -confirm_ps7 -deadline_user_name user
#>

# See:
# https://www.reddit.com/r/PowerShell/comments/jymq50/creating_a_windows_service_to_run_script_every/
# https://github.com/winsw/winsw/discussions/864
# https://github.com/winsw/winsw/blob/v3/docs/xml-config-file.md

param (
    [parameter(mandatory=$true)][ValidateSet("dev","green","blue")][string]$resourcetier,
    [parameter(mandatory=$true)][string]$deadline_user_name,
    # [parameter(mandatory=$false)][switch]$skip_configure_aws = $false,
    [parameter(mandatory=$false)][switch]$confirm_ps7 = $false,
    [parameter(mandatory=$false)][string]$aws_region,
    [parameter(mandatory=$false)][string]$aws_access_key,
    [parameter(mandatory=$false)][string]$aws_secret_key
)

$ErrorActionPreference = "Stop"

function Main {
    $appDir = "c:\AppData"
    $servicePath = "$appDir\myservice.exe"
    $pwshPath = "$appDir\myservice.ps1"

    $serviceName = "MyService"
    $myDownloadUrl="https://github.com/winsw/winsw/releases/download/v3.0.0-alpha.10/WinSW-x64.exe"

    # powershell -Command "Start-Process 'C:\Windows\SysWOW64\cmd.exe' -Verb RunAs -ArgumentList 'powershell Set-ExecutionPolicy RemoteSigned'"
    # powershell -Command "Start-Process 'C:\Windows\system32\cmd.exe' -Verb RunAs -ArgumentList 'powershell Set-ExecutionPolicy RemoteSigned'"
    if (-not $confirm_ps7) {
        Write-Host 'Ensure you run this script in a powershell 7 shell (with 
        admin priviledges) to install the service.
        '
        $answer = Read-Host -Prompt 'Have you followed the above steps? [Y/n]'
        if (-Not ("$answer".ToLower() -eq 'y')) {
            Write-Host "Exiting"
            exit
        }
    }

    if (-not $aws_region -or -not $aws_access_key -or -not $aws_secret_key) {
        Write-Host
        Write-Host "To aquire AWS credentials, run the following from the provisioner ec2 instance:"
        Write-Host "sudo su - ec2-user"
        Write-Host "cd server"
        Write-Host "source ./update_vars.sh"
        Write-Host "deploy/firehawk-main/modules/terraform-aws-vpn/modules/openvpn-vagrant-client/scripts/firehawk-auth-scripts/sign-ssh-key --generate-aws-key"
        Write-Host
        $aws_region = Read-Host -Prompt 'Enter your AWS Region:'
        $aws_access_key = Read-Host -Prompt 'Enter your AWS Access Key:'
        $aws_secret_key = Read-Host -Prompt 'Enter your AWS Secret Key:'
    }

    # if configure aws:
    # if (-not $skip_configure_aws) {
    $bash_script_path = $(wsl wslpath -a "'$PSScriptRoot\init-aws-auth-ssh'")
    bash "$bash_script_path" --resourcetier "$resourcetier" --aws-region "$aws_region" --aws-access-key "$aws_access_key" --aws-secret-key "$aws_secret_key" --no-prompts
    if (-not $LASTEXITCODE -eq 0) {
        Write-Warning "...Failed running: $bash_script_path"
        Write-Warning "LASTEXITCODE: $LASTEXITCODE"
        exit(1)
    }
    # }

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
    Copy-Item "$PSScriptRoot\pwsh-service\aws-auth-deadline-pwsh-cert.ps1" $appDir -Force
    Copy-Item "$PSScriptRoot\get-vault-file" $appDir -Force
    Copy-Item "$PSScriptRoot\request_stdout.sh" $appDir -Force

    "Replace env in service file with: $resoucetier"
    (Get-Content $appDir\myservice.ps1) -Replace "REPLACE_WITH_RESOURCETIER", "$resourcetier" | Set-Content $appDir\myservice.ps1
    (Get-Content $appDir\myservice.ps1) -Replace "REPLACE_WITH_DEADLINE_USER_NAME", "$deadline_user_name" | Set-Content $appDir\myservice.ps1
    (Get-Content $appDir\myservice.ps1) -Replace "REPLACE_WITH_AWS_REGION", "$aws_region" | Set-Content $appDir\myservice.ps1
    (Get-Content $appDir\myservice.ps1) -Replace "REPLACE_WITH_AWS_ACCESS_KEY", "$aws_access_key" | Set-Content $appDir\myservice.ps1
    (Get-Content $appDir\myservice.ps1) -Replace "REPLACE_WITH_AWS_SECRET_KEY", "$aws_secret_key" | Set-Content $appDir\myservice.ps1    
    "Download winsw"
    Invoke-WebRequest $myDownloadUrl -OutFile $servicePath
    "Installing service"
    & "$servicePath" install
    "Start service"
    & "$servicePath" start
    "Service Status"
    & "$servicePath" status

    "`nInstallation Completed"
    "`nTo observe logs, run:"
    "Get-Content C:\AppData\myservice.out.log -Wait"
}

try {
    Main
}
catch {
    $message = $_
    Write-Warning "Error running Main in: $PSCommandPath. $message"
    Write-Warning "Get-Error"
    Get-Error
    exit(1)
}