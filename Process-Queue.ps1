param(
    [string]$QueueFile = "C:\Scripts\CommandQueue\CommandQueue.json"
)

$LockFile = [System.IO.Path]::ChangeExtension($QueueFile, ".lock")

# Prevent concurrent runs
if (Test-Path $LockFile) {
    exit
}

New-Item $LockFile -ItemType File -Force | Out-Null

try {

    if (!(Test-Path $QueueFile)) {
        '{"jobs":[]}' | Out-File $QueueFile -Encoding utf8
    }

    $json = Get-Content $QueueFile -Raw

    if ([string]::IsNullOrWhiteSpace($json)) {
        $queue = [PSCustomObject]@{ jobs = @() }
    }
    else {
        $queue = $json | ConvertFrom-Json
    }

    if ($queue -eq $null) {
        $queue = [PSCustomObject]@{ jobs = @() }
    }

    $now = Get-Date
    $remainingJobs = @()

    foreach ($job in $queue.jobs) {

        $runTime = [datetime]$job.RunTime

        if ($runTime -le $now) {

            try {

                Write-Host "Running job $($job.Id)"

                $encoded = [Convert]::ToBase64String(
                    [System.Text.Encoding]::Unicode.GetBytes($job.Command)
                )

                Start-Process powershell.exe `
                    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" `
                    -WindowStyle Normal

            }
            catch {
                Write-Host "Failed job $($job.Id): $_"
            }

        }
        else {
            $remainingJobs += $job
        }
    }

    [PSCustomObject]@{ jobs = @($remainingJobs) } |
        ConvertTo-Json -Depth 5 |
        Out-File $QueueFile -Encoding utf8

}
finally {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
