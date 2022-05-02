Write-Host "Test Service"

$Timer = New-Object Timers.Timer
$Timer.Interval = 10000
$Timer.Enabled = $True
$objectEventArgs = @{
    InputObject = $Timer
    EventName = 'Elapsed'
    SourceIdentifier = 'myservicejob'
    Action = {
        Write-Host "Do stuff"
    }
}
$Job = Register-ObjectEvent @objectEventArgs
$Timer.Start()
$Job | Format-List -Property *
# Prevent the powershell process from exiting
$jobName = "myservicejob"
Write-Host "jobName: $jobName"
do {
    Start-Sleep -Milliseconds 1000
    $job = Get-Job -Name "$jobName"
} while ($job.State -in 'NotStarted', 'Running')

# & $Job.module {$Random}
# & $Job.module {$Random}