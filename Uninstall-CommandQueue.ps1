param(
    [switch]$RemoveQueue
)

$TaskName = "PowerShellCommandQueue"
$ScriptsFolder = "C:\Scripts\CommandQueue"
$QueueFile = "$ScriptsFolder\CommandQueue.json"
$ProcessScript = "$ScriptsFolder\Process-Queue.ps1"
$ScheduleScript = "$ScriptsFolder\Schedule-Command.ps1"
$CancelScript = "$ScriptsFolder\Cancel-Command.ps1"

Write-Host ""
Write-Host "Uninstalling Command Queue..."
Write-Host ""

# Remove scheduled task
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($task) {

    Unregister-ScheduledTask `
        -TaskName $TaskName `
        -Confirm:$false

    Write-Host "Scheduled task removed."

}
else {
    Write-Host "Scheduled task not found."
}

# Remove QueueFile if requested
if ($RemoveQueue) {

    if (Test-Path $ScriptsFolder) {

        Remove-Item $QueueFile 

        Write-Host "Queue removed."
    }

}
else {

    Write-Host ""
    Write-Host "Queue not removed."
    Write-Host "Use -RemoveQueue to delete all queue files."
}

Write-Host ""
Write-Host "Uninstall complete."
Write-Host ""