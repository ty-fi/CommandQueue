$Script:QueueFile = "C:\Scripts\CommandQueue\CommandQueue.json"

function Convert-NaturalLanguageToDateTime {

    param([string]$InputString)

    $now = Get-Date
    $input = $InputString.ToLower().Trim()

    try { return [datetime]::Parse($InputString) } catch {}

    if ($input -match "^in\s+(\d+)\s+(minute|minutes|hour|hours|day|days)$") {

        $value = [int]$matches[1]
        $unit = $matches[2]

        switch ($unit) {
            {$_ -like "minute*"} { return $now.AddMinutes($value) }
            {$_ -like "hour*"}   { return $now.AddHours($value) }
            {$_ -like "day*"}    { return $now.AddDays($value) }
        }
    }

    if ($input -match "^tomorrow(?:\s+at\s+(.+))?$") {

        if ($matches[1]) {
            $t = [datetime]::Parse($matches[1])
            return (Get-Date).Date.AddDays(1).Add($t.TimeOfDay)
        }

        return (Get-Date).Date.AddDays(1)
    }

    if ($input -match "^today\s+at\s+(.+)$") {

        $t = [datetime]::Parse($matches[1])
        return (Get-Date).Date.Add($t.TimeOfDay)
    }

    throw "Could not parse time string."
}

function Register-ScheduledCommand {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('c')]
        [string]$Command,

        [Parameter(Mandatory)]
        [Alias('t')]
        [string]$Time
    )

    if (!(Test-Path $Script:QueueFile)) {
        '{"jobs":[]}' | Out-File $Script:QueueFile -Encoding utf8
    }

    $RunTime = Convert-NaturalLanguageToDateTime $Time

    if ($RunTime -le (Get-Date)) {
        throw "Time must be in the future."
    }

    $queue = Get-Content $Script:QueueFile -Raw | ConvertFrom-Json

    if ($queue -eq $null) {
        $queue = [PSCustomObject]@{ jobs = @() }
    }

    $job = [PSCustomObject]@{

        Id = [guid]::NewGuid().ToString()

        Command = $Command

        RunTime = $RunTime
    }

    $queue.jobs = @($queue.jobs) + @($job)

    $queue | ConvertTo-Json -Depth 5 |
        Out-File $Script:QueueFile -Encoding utf8

    Write-Host ""
    Write-Host "Registered:"
    Write-Host $Command
    Write-Host "At:"
    Write-Host $RunTime
    Write-Host ""
}

function Get-ScheduledCommand {

    [CmdletBinding()]
    param(
        [switch]$Detailed
    )

    if (!(Test-Path $Script:QueueFile)) {
        Write-Host "Queue empty."
        return
    }

    $queue = Get-Content $Script:QueueFile -Raw |
        ConvertFrom-Json

    if (!$queue -or !$queue.jobs) {
        Write-Host "Queue empty."
        return
    }

    $queue.jobs |
    Sort-Object RunTime |
    Select-Object `
        Id,
        RunTime,
        @{Name="MinutesRemaining";Expression={
            [math]::Round(
                (([datetime]$_.RunTime) - (Get-Date)).TotalMinutes, 2)
        }},
        Command
}

function Remove-ScheduledCommand {

    [CmdletBinding()]
    param(
        [string]$Id,
        [switch]$All
    )

    if (!(Test-Path $Script:QueueFile)) {
        Write-Host "Queue empty."
        return
    }

    if ($All) {

        '{"jobs":[]}' | Out-File $Script:QueueFile -Encoding utf8

        Write-Host "All jobs removed."
        return
    }

    if (!$Id) {
        throw "Specify -Id or -All"
    }

    $queue = Get-Content $Script:QueueFile -Raw |
        ConvertFrom-Json

    $queue.jobs = @($queue.jobs | Where-Object Id -ne $Id)

    $queue | ConvertTo-Json -Depth 5 |
        Out-File $Script:QueueFile -Encoding utf8

    Write-Host "Job removed."
}

Export-ModuleMember `
    -Function Register-ScheduledCommand,
              Get-ScheduledCommand,
              Remove-ScheduledCommand
