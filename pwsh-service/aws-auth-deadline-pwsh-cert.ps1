#Requires -Version 7.0

param (
    [parameter(mandatory)][string]$resourcetier
)

$ErrorActionPreference = "Stop"

# aws ssm get-parameters --with-decryption --names /firehawk/resourcetier/dev/sqs_remote_in_deadline_cert_url

function SSM-Get-Parm {
    param (
        [string]$parm_name
    )
    Write-Host "...Get ssm parameter:"
    Write-Host "$parm_name"
    $output = $(aws ssm get-parameters --with-decryption --output json --names $parm_name | ConvertFrom-Json)
    $invalid = $($output.InvalidParameters.Length)
    if ($LASTEXITCODE -eq 0 -and $invalid -eq 0) {
        $value = $($output.Parameters.Value)
        return $value
    }
    Write-Warning "...Failed retrieving: $parm_name"
    Write-Warning "Result: $output"
    exit(1)
}
function Poll-Sqs-Queue {
    <#
    .SYNOPSIS
    Poll an AWS SQS queue for a message
    .DESCRIPTION
    Gets a value from an SQS queue, optionally draining the message.
    .PARAMETER resourcetier
    Specifies the environment.
    .PARAMETER parm_name
    Specifies the parameter name to aquire
    .INPUTS
    None. You cannot pipe objects to Poll-Sqs-Queue.
    .OUTPUTS
    System.String. Poll-Sqs-Queue returns nothing.
    .EXAMPLE
    PS> Poll-Sqs-Queue -resourcetier 'dev'
    .LINK
    http://www.firehawkvfx.com
    #>
    param (
        [parameter(mandatory)][string]$resourcetier,
        [string]$parm_name = "/firehawk/resourcetier/$resourcetier/sqs_remote_in_deadline_cert_url",
        [string]$sqs_queue_url = $(SSM-Get-Parm $parm_name),
        [string]$drain_queue = $false,
        [float]$default_poll_duration = 5,
        [float]$max_count = 1
    )

    Write-Host "...Polling SQS queue"
    $count = 0
    $poll = $true

    while ($poll) {
        $count += 1
        $msg = "$(aws sqs receive-message --queue-url $sqs_queue_url --output json | ConvertFrom-Json)"
        Write-Host "msg: $msg"
        if ($msg) {
            $poll = $false
            if ($drain_queue) {
                $receipt_handle = $($msg.Messages.ReceiptHandle)
                if (-not $LASTEXITCODE -eq 0 -or -not $receipt_handle) {
                    Write-Error "Couldn't get receipt_handle: $receipt_handle"
                    exit(1)
                }
                aws sqs delete-message --queue-url $sqs_queue_url --receipt-handle $receipt_handle
                if (-not $LASTEXITCODE -eq 0) {
                    return $msg.Messages.Body
                } else {
                    Write-Host "Error during aws sqs delete-message"
                }
            } else {
                return $msg.Messages.Body
            }

        }

        if ($poll) {
            if ($max_count -gt 0 -and $count -ge $max_count) {
                $poll = $false
                Write-Host "Max count reached."
            } else {
                Write-Host "...Waiting $default_poll_duration seconds before retry."
                Start-Sleep -Seconds $default_poll_duration
            }
        }
    }
}

function Get-Cert-Fingerprint {
    param (
        [parameter(mandatory)][string]$file_path,
        [string]$cert_password=""
    )
    # current_fingerprint="$(openssl pkcs12 -in $file_path -nodes -passin pass: |openssl x509 -noout -fingerprint)"
    $certificateObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($file_path, $cert_password)
    return $certificateObject
}

function Test-Service-Up {
    param (
        [parameter(mandatory)][string]$deadline_client_cert_fingerprint
    )
    Write-Host "...Try to get fingerprint from local certificate"
    $source_file_path = "/opt/Thinkbox/certs/Deadline10RemoteClient.pfx" # the original file path that was stored in vault
    $target_path="$HOME/.ssh/$($source_file_path | Split-Path -Leaf)"
    if (Test-Path $target_path) {
        Write-Host "Local certificate exists."
        $local_fingerprint=$(Get-Cert-Fingerprint -file_path $target_path)
        if ($deadline_client_cert_fingerprint -eq $local_fingerprint) {
            return $true
        } else {
            Write-Host "Local cert fingerprint doesn't match."
            Write-Host "deadline_client_cert_fingerprint: $deadline_client_cert_fingerprint"
            Write-Host "local: $local_fingerprint"
            return $false
        }
    } else {
        Write-Host "No local certificate exists yet."
    }
}

function Get-Cert-From-Vault-Proxy {
    param (
        [parameter(mandatory)][string]$resourcetier,
        [parameter(mandatory)][string]$host1,
        [parameter(mandatory)][string]$host2,
        [parameter(mandatory)][string]$vault_token
    )
    Write-Host "Request the deadline client certificate from proxy."
    $source_file_path="/opt/Thinkbox/certs/Deadline10RemoteClient.pfx" # the original file path that was stored in vault
    $source_vault_path="$resourcetier/data/deadline/client_cert_files$source_file_path" # the full namespace / path to the file in vault.
    $tmp_target_path="$HOME/.ssh/_$($source_file_path | Split-Path -Leaf)"
    $target_path="$HOME/.ssh/$($source_file_path | Split-Path -Leaf)"
    if (Test-Path -Path $tmp_target_path) {
        Remove-Item -Path $tmp_target_path
    }
    Get-Vault-File -host1 $host1 -host2 $host2 -source_vault_path $source_vault_path -target-path $tmp_target_path -vault-token $vault_token
    Move-Item -Path $tmp_target_path -Destination $target_path
}

function Get-Vault-File {
    param (
        [parameter(mandatory)][string]$host1,
        [parameter(mandatory)][string]$host2,
        [parameter(mandatory)][string]$source_vault_path,
        [parameter(mandatory)][string]$vault_token,
        [parameter(mandatory)][string]$target_path,
        [parameter()][string]$local_request=$false
    )
    
    $env:VAULT_TOKEN = $vault_token

    $bastion_user=$host1.split('@')[0]
    Write-Host "Aquiring file from Vault"
    if (-not $local_request) {
        Write-Host "Aquiring file from Vault with ssh proxy"
        Get-File-Stdout-Proxy -host1 "$host1" -host2 "$host2" -vault_token "$vault_token" -source_vault_token "$source_vault_path" -target_path "$target_path"
    } else {
        Write-Host "Aquiring file from Vault with localhost"
        Get-File-Stdout-Local -vault_token "$vault_token" -source_vault_path "$source_vault_path" -target_path "$target_path"
    }

    if (Test-Path -Path $target_path){
        Write-Host "File acquired!"
    } else {
        Write-Warning "Could not aquire data. Aborting."
        exit(1)
    }
}

function Get-File-Stdout-Local {
    param (
        [parameter(mandatory)][string]$token,
        [parameter(mandatory)][string]$source_vault_path,
        [parameter(mandatory)][string]$target_path
    )
    Write-Host "Local Vault request"
    Write-Host "Retrieve: $source_vault_path"

    response=$(bash $PSScriptRoot/request_stdout.sh "$source_vault_path/file" "$token")
    Stdout-To-File -response "$response" -target_path "$target_path"
}

function Get-File-Stdout-Proxy {
    param (
        [parameter(mandatory)][string]$host1,
        [parameter(mandatory)][string]$host2,
        [parameter(mandatory)][string]$vault_token,
        [parameter(mandatory)][string]$source_vault_path,
        [parameter(mandatory)][string]$target_path,
        [parameter()][string]$local_request=$false
    )
    if ($IsWindows) {
        # For windows the system wide ssh known_hosts is not known.
        ssh_known_hosts_path="$HOME/.ssh/known_hosts"
    } elseif ($IsMacOs) {
        ssh_known_hosts_path="/usr/local/etc/ssh/ssh_known_hosts"
    } elseif ($IsLinux) {
        ssh_known_hosts_path="/etc/ssh/ssh_known_hosts"
    } else {
        throw "Something has gone wronge because the os could not be determined"
    }

    response=$(ssh -i "$HOME/.ssh/id_rsa-cert.pub" -i "$HOME/.ssh/id_rsa" -o UserKnownHostsFile="$ssh_known_hosts_path" -o ProxyCommand="ssh -i \"$HOME/.ssh/id_rsa-cert.pub\" -i \"$HOME/.ssh/id_rsa\" -o UserKnownHostsFile=\"$ssh_known_hosts_path\" $host1 -W %h:%p" $host2 "bash -s" < $PSScriptRoot/request_stdout.sh "$source_vault_path/file" "$token" | ConvertFrom-Json)

    Stdout-To-File -response $response -target_path $target_path
}
function Stdout-To-File {
    param (
        [parameter(mandatory)][string]$response,
        [parameter(mandatory)][string]$target_path
    )
    $errors = $(response.errors.Length)
    if (-not $errors -eq 0) {
        Write-Warning "Vault request failed. response: $response"
        exit(1)
    }
    Write-Host "stdout_to_file mkdir: $(Split-Path -parent $target_path)"
    New-Item $(Split-Path -parent $target_path) -ItemType Directory -ea 0
    Write-Host "Write file content from stdout..."
    $response.data.data.value | Out-File -FilePath $target_path
    $content = $(Get-Content -Path $target_path)
    if (-not $(Test-Path -Path $target_path)) {
        Write-Warning "Error: no file at $target_path"
        exit(1)
    } elseif (-not $content) {
        Write-Warning "Error: no content in $target_path"
        exit(1)
    }
    Write-Host "Request Complete."
}

function Main {
    param (
        [parameter(mandatory)][string]$resourcetier
    )
    $result=$(Poll-Sqs-Queue -resourcetier $resourcetier)
    Write-Host "...Get fingerprint from SQS Message"
    $deadline_client_cert_fingerprint=$($result.deadline_client_cert_fingerprint)
    Write-Host "deadline_client_cert_fingerprint: $deadline_client_cert_fingerprint"
    if ($deadline_client_cert_fingerprint -eq "null") {
        Write-Warning "No fingerprint in message.  The invalid message should not have been sent: fingerprint: $deadline_client_cert_fingerprint"
        exit(1)
    } elseif (-not $deadline_client_cert_fingerprint) {
        Write-Host "No SQS message available to validate with yet."
        exit(0)
    } elseif (-not $(Test-Service-Up $deadline_client_cert_fingerprint)) {
        Write-Host "Deadline cert fingerprint is not current (No Match).  Will update. Fingerprint: $deadline_client_cert_fingerprint"
        Write-Host "...Getting SQS endpoint from SSM Parameter and await SQS message for VPN credentials."

        if ($result) {
            $host1 = $result.host1
            $host2 = $result.host2
            $vault_token = $result.token
            Get-Cert-From-Vault-Proxy "$resourcetier" "$host1" "$host2" "$vault_token"
        } else {
            Write-Host "No payload aquired"
        }
    } else {
        Write-Host "Deadline certificate matches current remote certificate."
    }
}

Main -resourcetier $resourcetier