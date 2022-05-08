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
                # bash /mnt/c/AppData/aws-auth-deadline-cert --resourcetier 'dev'
                C:\AppData\aws-auth-deadline-pwsh-cert.ps1 -resourcetier 'REPLACE_WITH_RESOURCETIER' -deadline_user_name 'REPLACE_WITH_DEADLINE_USER_NAME' -aws_region 'REPLACE_WITH_AWS_REGION' -aws_access_key 'REPLACE_WITH_AWS_ACCESS_KEY' -aws_secret_key 'REPLACE_WITH_AWS_SECRET_KEY'
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
