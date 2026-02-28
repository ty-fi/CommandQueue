$ScriptsFolder = "C:\Scripts\CommandQueue"
$ProcessScript = "$ScriptsFolder\Process-Queue.ps1"
$QueueFile = "$ScriptsFolder\CommandQueue.json"
$TaskName = "PowerShellCommandQueue"

# Create folder if missing
if (!(Test-Path $ScriptsFolder)) {
    New-Item -ItemType Directory -Path $ScriptsFolder -Force | Out-Null
}

# Create empty queue file if missing
if (!(Test-Path $QueueFile)) {
    "[]" | Out-File $QueueFile -Encoding utf8
}

# Startup trigger
$StartupTrigger = New-ScheduledTaskTrigger -AtStartup

# Repeating trigger every 5 minutes indefinitely
$RepeatTrigger = New-ScheduledTaskTrigger `
    -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 365)

# Action
$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ProcessScript`""

# Settings
$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew

# Register task as SYSTEM
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger @($StartupTrigger, $RepeatTrigger) `
    -Settings $Settings `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force

Write-Host ""
Write-Host "Command Queue installed successfully."
Write-Host "Runs as SYSTEM at startup and every 5 minutes."
Write-Host ""