
$ErrorActionPreference = "Stop"

# aws ssm get-parameters --with-decryption --names /firehawk/resourcetier/dev/sqs_remote_in_deadline_cert_url

function SSM-Get-Parm {
    param (
        [string]$parm_name
    )
    Write-Host "...Get ssm parameter:"
    Write-Host "$parm_name"
    $output=$(aws ssm get-parameters --with-decryption --output json --names $parm_name | ConvertFrom-Json)
    $invalid=$($output.InvalidParameters.Length)
    if ($LASTEXITCODE -eq 0 -and $invalid -eq 0) {
        $value=$($output.Parameters.Value)
        return $value
    }
    Write-Warning "...Failed retrieving: $parm_name"
    Write-Warning "Result: $output"
    exit(1)
}
function Poll-Sqs-Queue {
    <#
    .SYNOPSIS
    Adds a file name extension to a supplied name.
    .DESCRIPTION
    Adds a file name extension to a supplied name.
    Takes any strings for the file name or extension.
    .PARAMETER Name
    Specifies the file name.
    .PARAMETER Extension
    Specifies the extension. "Txt" is the default.
    .INPUTS
    None. You cannot pipe objects to Poll-Sqs-Queue.
    .OUTPUTS
    System.String. Poll-Sqs-Queue returns a string with the extension
    or file name.
    .EXAMPLE
    PS> extension -name "File"
    File.txt
    .EXAMPLE
    PS> extension -name "File" -extension "doc"
    File.doc
    .EXAMPLE
    PS> extension "File" "doc"
    File.doc
    .LINK
    http://www.fabrikam.com/extension.html
    .LINK
    Set-Item
    #>
    param (
        [string]$Resourcetier,
        [string]$parm_name = "/firehawk/resourcetier/$Resourcetier/sqs_remote_in_deadline_cert_url",
        [string]$sqs_queue_url = $(SSM-Get-Parm $parm_name),
        [string]$drain_queue = $false
    )
    # $sqs_queue_url = $(SSM-Get-Parm $parm_name)
    Write-Host $sqs_queue_url


}

function Main {
    Poll-Sqs-Queue -Resourcetier 'dev'

}

Main