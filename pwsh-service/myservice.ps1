#Requires -Version 7.0

Write-Host "Start Service"

# $ErrorActionPreference = "Stop"

function Main {
    $Timer = New-Object Timers.Timer
    $Timer.Interval = 10000
    $Timer.Enabled = $True
    $Timer.AutoReset = $True
    $objectEventArgs = @{
        InputObject = $Timer
        EventName = 'Elapsed'
        SourceIdentifier = 'myservicejob'
        Action = {
            try {
                $resourcetier = "dev"
                Write-Host "Run aws-auth-deadline-cert"
                Set-strictmode -version latest
                . C:\AppData\myservice-config.ps1
                C:\AppData\aws-auth-deadline-pwsh-cert.ps1 -resourcetier $resourcetier -deadline_user_name $deadline_user_name -aws_region $aws_region -aws_access_key $aws_access_key -aws_secret_key $aws_secret_key
                Write-Host "Finished running aws-auth-deadline-cert"
            } catch {
                Write-Warning "Error in service Action{} block"
                exit(1)
            }
        }
    }
    $Job = Register-ObjectEvent @objectEventArgs

    Wait-Event
}

try {
    Main
}
catch {
    Write-Warning "Error running Main in: $PSCommandPath"
    exit(1)
}
