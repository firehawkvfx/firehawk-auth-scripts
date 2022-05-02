Write-Host "Test Service"

$Timer = New-Object Timers.Timer
$Timer.Interval = 10000
$Timer.Enabled = $True
$Timer.AutoReset = $True
$objectEventArgs = @{
    InputObject = $Timer
    EventName = 'Elapsed'
    SourceIdentifier = 'myservicejob'
    Action = {
        Write-Host "Do stuff"
    }
}
$Job = Register-ObjectEvent @objectEventArgs
# $Timer.Start()
# $Job | Format-List -Property *

Wait-Event

# & $Job.module {$Random}
# & $Job.module {$Random}