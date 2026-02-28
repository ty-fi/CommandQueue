$ScriptsFolder = "C:\Scripts\CommandQueue"
$QueueFile = "$ScriptsFolder\CommandQueue.json"
$LockFile = "C:\Scripts\CommandQueue.lock"

# Prevent concurrent runs
if (Test-Path $LockFile) {
    exit
}

New-Item $LockFile -ItemType File -Force | Out-Null

try {

    if (!(Test-Path $QueueFile)) {
        "[]" | Out-File $QueueFile -Encoding utf8
    }

    $json = Get-Content $QueueFile -Raw

    if ([string]::IsNullOrWhiteSpace($json)) {
        $queue = @()
    }
    else {
        $queue= $json | ConvertFrom-Json
    }

    if ($queue -eq $null) {
        $queue = @()
    }

    $now = Get-Date
    $remainingJobs = @()

    foreach ($job in $queue.jobs) {

        $runTime = [datetime]$job.RunTime

        if ($runTime -le $now) {

            try {

                Write-Host "Running job $($job.Id)"

                Start-Process powershell.exe `
                    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $($job.Command)" `
                    -WindowStyle Normal

            }
            catch {
                Write-Host "Failed job $($job.Id)"
            }

        }
        else {
            $remainingJobs += $job
        }
    }

    $remainingJobs | ConvertTo-Json -Depth 5 | Out-File $QueueFile -Encoding utf8

}
finally {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}