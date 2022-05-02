Write-Host "Test Service"

$ErrorActionPreference = "Stop"

$Timer = New-Object Timers.Timer
$Timer.Interval = 10000
$Timer.Enabled = $True
$Timer.AutoReset = $True
$objectEventArgs = @{
    InputObject = $Timer
    EventName = 'Elapsed'
    SourceIdentifier = 'myservicejob'
    Action = {
        $resourcetier = "dev"

        $ErrorActionPreference = "Stop"
        
        Write-Host "Run aws-auth-deadline-cert"
        bash /mnt/c/AppData/aws-auth-deadline-cert --resourcetier 'dev'
        Write-Host "Finished running aws-auth-deadline-cert"
    }
}
$Job = Register-ObjectEvent @objectEventArgs

Wait-Event