# CommandQueue

A lightweight PowerShell command scheduler built on Windows Task Scheduler. Queue any command to run at a future time using natural language or a specific datetime — no third-party dependencies required.

## How it works

1. You add commands to the queue with `Register-ScheduledCommand`
2. A Windows Scheduled Task runs `Process-Queue.ps1` every 5 minutes
3. When a command's scheduled time arrives, it executes in a new PowerShell window and is removed from the queue

The queue is stored as a local JSON file. The scheduled task runs as SYSTEM so it fires even when your user session is locked.

## Requirements

- Windows PowerShell 5.1+
- Windows Task Scheduler (built into Windows)
- Administrator rights (installation only)

## Authorization

Windows restricts script execution by default. Two things may need to be addressed before the module works.

**1. Execution policy**

Check your current policy:

```powershell
Get-ExecutionPolicy -Scope CurrentUser
```

If it returns `Restricted` or `Undefined`, allow local scripts to run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

`RemoteSigned` lets you run local scripts freely while still requiring scripts downloaded from the internet to be signed. No Administrator rights needed for the `CurrentUser` scope.

**2. Unblock files cloned from GitHub**

When Git clones files from the internet, Windows marks them as untrusted. Unblock them before importing:

```powershell
Get-ChildItem -Path C:\Scripts\CommandQueue -Recurse | Unblock-File
```

You can verify a file is unblocked by checking that this returns nothing:

```powershell
Get-Item C:\Scripts\CommandQueue\CommandQueue.psm1 -Stream Zone.Identifier -ErrorAction SilentlyContinue
```

## Installation

**1. Register the scheduled task** (run once as Administrator):

```powershell
.\Install-CommandQueue.ps1
```

This creates a task that runs at startup and repeats every 5 minutes.

**2. Import the module** — add this to your PowerShell profile (`$PROFILE`) so the commands are available in every session:

```powershell
Import-Module C:\Scripts\CommandQueue\CommandQueue.psm1
```

## Usage

### Schedule a command

```powershell
Register-ScheduledCommand -Command "shutdown /r /t 0" -Time "in 2 hours"
Register-ScheduledCommand -Command "Write-Host 'Stand up'" -Time "today at 3:00 PM"
Register-ScheduledCommand -Command "notepad.exe C:\notes.txt" -Time "tomorrow at 9:00 AM"

# Short aliases
Register-ScheduledCommand -c "explorer.exe" -t "in 30 minutes"
```

**Supported time formats:**

| Input | Meaning |
|---|---|
| `in N minutes` | N minutes from now |
| `in N hours` | N hours from now |
| `in N days` | N days from now |
| `today at HH:MM AM/PM` | Later today |
| `tomorrow` | Midnight tomorrow |
| `tomorrow at HH:MM AM/PM` | Specific time tomorrow |
| Any datetime string | Parsed by `[datetime]::Parse()` |

### View the queue

```powershell
Get-ScheduledCommand
```

```
Id                                   RunTime              MinutesRemaining Command
--                                   -------              ---------------- -------
3f2a1b4c-...                         2/28/2026 3:00:00 PM            42.3 Write-Host 'Stand up'
9e8d7c6b-...                         3/1/2026  9:00:00 AM           975.1 notepad.exe C:\notes.txt
```

### Remove a job

```powershell
# Remove a specific job by its Id
Remove-ScheduledCommand -Id 3f2a1b4c-...

# Clear all jobs
Remove-ScheduledCommand -All
```

## Uninstall

```powershell
# Remove the scheduled task only
.\Uninstall-CommandQueue.ps1

# Remove the scheduled task and the queue file
.\Uninstall-CommandQueue.ps1 -RemoveQueue
```

## Running tests

Pester 3.4 ships with Windows. From the repo root:

```powershell
Import-Module Pester
Invoke-Pester .\Tests\CommandQueue.Tests.ps1
```

## File reference

| File | Purpose |
|---|---|
| `CommandQueue.psm1` | Module — exports `Register-ScheduledCommand`, `Get-ScheduledCommand`, `Remove-ScheduledCommand` |
| `Install-CommandQueue.ps1` | Registers the Windows Scheduled Task (run as Admin) |
| `Process-Queue.ps1` | Processes due jobs; called by Task Scheduler every 5 minutes |
| `Uninstall-CommandQueue.ps1` | Removes the scheduled task |
| `Tests/CommandQueue.Tests.ps1` | Pester test suite (22 tests) |
