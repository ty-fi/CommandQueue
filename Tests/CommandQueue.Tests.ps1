#
# CommandQueue.Tests.ps1 -- Pester 3.4 test suite
#
# Run from any location:
#   Import-Module Pester
#   Invoke-Pester C:\Scripts\CommandQueue\Tests\CommandQueue.Tests.ps1
#

$ModulePath    = Resolve-Path "$PSScriptRoot\..\CommandQueue.psm1"
$ProcessScript = Resolve-Path "$PSScriptRoot\..\Process-Queue.ps1"

# Environment variable lets InModuleScope (which runs in module scope, not
# the caller's scope) see the test file path without needing $using: syntax.
$env:CQ_TEST_FILE = Join-Path $PSScriptRoot "TestQueue.json"
$TestQueueFile    = $env:CQ_TEST_FILE

# Load (or reload) the module
if (Get-Module CommandQueue) { Remove-Module CommandQueue -Force }
Import-Module $ModulePath -DisableNameChecking

# Redirect the module to the test queue file so production queue is untouched
InModuleScope CommandQueue { $Script:QueueFile = $env:CQ_TEST_FILE }

function Reset-TestQueue {
    '{"jobs":[]}' | Out-File $env:CQ_TEST_FILE -Encoding utf8
}

function Get-TestQueue {
    Get-Content $env:CQ_TEST_FILE -Raw | ConvertFrom-Json
}

# ---------------------------------------------------------------
Describe "Convert-NaturalLanguageToDateTime" {

    It "Parses 'in 5 minutes'" {
        InModuleScope CommandQueue {
            $result = Convert-NaturalLanguageToDateTime "in 5 minutes"
            $result | Should BeGreaterThan (Get-Date)
            $result | Should BeLessThan (Get-Date).AddMinutes(6)
        }
    }

    It "Parses 'in 2 hours'" {
        InModuleScope CommandQueue {
            $result = Convert-NaturalLanguageToDateTime "in 2 hours"
            $result | Should BeGreaterThan (Get-Date).AddHours(1)
            $result | Should BeLessThan (Get-Date).AddHours(3)
        }
    }

    It "Parses 'in 1 day'" {
        InModuleScope CommandQueue {
            $result = Convert-NaturalLanguageToDateTime "in 1 day"
            $result | Should BeGreaterThan (Get-Date).AddHours(23)
        }
    }

    It "Parses 'tomorrow'" {
        InModuleScope CommandQueue {
            $result = Convert-NaturalLanguageToDateTime "tomorrow"
            $result.Date | Should Be ((Get-Date).Date.AddDays(1))
        }
    }

    It "Parses 'today at 11:59 PM'" {
        InModuleScope CommandQueue {
            $result = Convert-NaturalLanguageToDateTime "today at 11:59 PM"
            $result.Date   | Should Be (Get-Date).Date
            $result.Hour   | Should Be 23
            $result.Minute | Should Be 59
        }
    }

    It "Throws on unparseable input" {
        InModuleScope CommandQueue {
            { Convert-NaturalLanguageToDateTime "next banana" } | Should Throw
        }
    }
}

# ---------------------------------------------------------------
Describe "Schedule-Command" {

    BeforeEach { Reset-TestQueue }
    AfterEach  { if (Test-Path $env:CQ_TEST_FILE) { Remove-Item $env:CQ_TEST_FILE -Force } }

    It "Adds a job to an empty queue" {
        Schedule-Command -Command "Write-Host Hello" -Time "in 5 minutes"

        $q = Get-TestQueue
        $q.jobs.Count      | Should Be 1
        $q.jobs[0].Command | Should Be "Write-Host Hello"
    }

    It "Adds a second job and queue grows to 2" {
        Schedule-Command -Command "Write-Host First"  -Time "in 5 minutes"
        Schedule-Command -Command "Write-Host Second" -Time "in 10 minutes"

        $q = Get-TestQueue
        $q.jobs.Count | Should Be 2
    }

    It "Adds three jobs and queue grows to 3" {
        Schedule-Command -Command "Write-Host A" -Time "in 5 minutes"
        Schedule-Command -Command "Write-Host B" -Time "in 10 minutes"
        Schedule-Command -Command "Write-Host C" -Time "in 15 minutes"

        $q = Get-TestQueue
        $q.jobs.Count | Should Be 3
    }

    It "Each job gets a unique GUID Id" {
        Schedule-Command -Command "Write-Host A" -Time "in 5 minutes"
        Schedule-Command -Command "Write-Host B" -Time "in 10 minutes"

        $q = Get-TestQueue
        $q.jobs[0].Id | Should Not Be $q.jobs[1].Id
    }

    It "Rejects a time in the past" {
        { Schedule-Command -Command "Write-Host Past" -Time "2020-01-01" } | Should Throw
    }
}

# ---------------------------------------------------------------
Describe "Get-CommandQueue" {

    BeforeEach { Reset-TestQueue }
    AfterEach  { if (Test-Path $env:CQ_TEST_FILE) { Remove-Item $env:CQ_TEST_FILE -Force } }

    It "Does not throw when queue is empty" {
        { Get-CommandQueue } | Should Not Throw
    }

    It "Lists a scheduled job with correct fields" {
        Schedule-Command -Command "Write-Host Listed" -Time "in 5 minutes"

        $result = Get-CommandQueue
        $result                     | Should Not BeNullOrEmpty
        $result[0].Command          | Should Be "Write-Host Listed"
        $result[0].MinutesRemaining | Should BeGreaterThan 0
    }

    It "Returns jobs sorted by RunTime ascending" {
        Schedule-Command -Command "Write-Host Late"  -Time "in 30 minutes"
        Schedule-Command -Command "Write-Host Early" -Time "in 5 minutes"

        $result = Get-CommandQueue
        $result[0].Command | Should Be "Write-Host Early"
        $result[1].Command | Should Be "Write-Host Late"
    }
}

# ---------------------------------------------------------------
Describe "Remove-CommandQueue" {

    BeforeEach { Reset-TestQueue }
    AfterEach  { if (Test-Path $env:CQ_TEST_FILE) { Remove-Item $env:CQ_TEST_FILE -Force } }

    It "Removes a job by Id" {
        Schedule-Command -Command "Write-Host Delete Me" -Time "in 5 minutes"
        $id = (Get-TestQueue).jobs[0].Id

        Remove-CommandQueue -Id $id

        (Get-TestQueue).jobs.Count | Should Be 0
    }

    It "Leaves other jobs intact when removing by Id" {
        Schedule-Command -Command "Write-Host Keep"   -Time "in 5 minutes"
        Schedule-Command -Command "Write-Host Remove" -Time "in 10 minutes"

        $removeId = ((Get-TestQueue).jobs | Where-Object Command -eq "Write-Host Remove").Id
        Remove-CommandQueue -Id $removeId

        $q = Get-TestQueue
        $q.jobs.Count      | Should Be 1
        $q.jobs[0].Command | Should Be "Write-Host Keep"
    }

    It "Removes all jobs with -All" {
        Schedule-Command -Command "Write-Host A" -Time "in 5 minutes"
        Schedule-Command -Command "Write-Host B" -Time "in 10 minutes"

        Remove-CommandQueue -All

        (Get-TestQueue).jobs.Count | Should Be 0
    }

    It "Queue file retains jobs structure after -All" {
        Remove-CommandQueue -All

        $q = Get-TestQueue
        # In Pester 3.4 'Should Contain' checks file contents; use -contains for arrays
        ($q.PSObject.Properties.Name -contains "jobs") | Should Be $true
    }
}

# ---------------------------------------------------------------
Describe "Process-Queue" {

    BeforeEach { Reset-TestQueue }
    AfterEach  {
        if (Test-Path $env:CQ_TEST_FILE) { Remove-Item $env:CQ_TEST_FILE -Force }
        $lockFile = [System.IO.Path]::ChangeExtension($env:CQ_TEST_FILE, ".lock")
        if (Test-Path $lockFile) { Remove-Item $lockFile -Force }
    }

    It "Removes a due job from the queue" {
        $pastJob = [PSCustomObject]@{
            Id      = [guid]::NewGuid().ToString()
            Command = "Write-Host ProcessTest"
            RunTime = (Get-Date).AddMinutes(-1).ToString("o")
        }
        [PSCustomObject]@{ jobs = @($pastJob) } |
            ConvertTo-Json -Depth 5 |
            Out-File $env:CQ_TEST_FILE -Encoding utf8

        & $ProcessScript -QueueFile $env:CQ_TEST_FILE

        (Get-TestQueue).jobs.Count | Should Be 0
    }

    It "Keeps a future job in the queue" {
        Schedule-Command -Command "Write-Host Future" -Time "in 30 minutes"

        & $ProcessScript -QueueFile $env:CQ_TEST_FILE

        $q = Get-TestQueue
        $q.jobs.Count      | Should Be 1
        $q.jobs[0].Command | Should Be "Write-Host Future"
    }

    It "Runs due jobs and keeps future jobs" {
        $pastJob = [PSCustomObject]@{
            Id      = [guid]::NewGuid().ToString()
            Command = "Write-Host Past"
            RunTime = (Get-Date).AddMinutes(-1).ToString("o")
        }
        [PSCustomObject]@{ jobs = @($pastJob) } |
            ConvertTo-Json -Depth 5 |
            Out-File $env:CQ_TEST_FILE -Encoding utf8

        Schedule-Command -Command "Write-Host Future" -Time "in 30 minutes"

        & $ProcessScript -QueueFile $env:CQ_TEST_FILE

        $q = Get-TestQueue
        $q.jobs.Count      | Should Be 1
        $q.jobs[0].Command | Should Be "Write-Host Future"
    }

    It "Queue file has correct jobs structure after processing" {
        Schedule-Command -Command "Write-Host Struct" -Time "in 5 minutes"

        & $ProcessScript -QueueFile $env:CQ_TEST_FILE

        $q = Get-TestQueue
        ($q.PSObject.Properties.Name -contains "jobs") | Should Be $true
    }
}
