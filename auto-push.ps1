Param(
    [string]$Path = '.',
    [int]$DelaySeconds = 3,
    [string]$CommitPrefix = 'Auto-save'
)

Set-Location $Path
if (-not (Test-Path ".git")) {
    Write-Error "Not a git repository at $Path. Initialize or run inside a repo."
    exit 1
}

$global:pending = $false
$timer = New-Object System.Timers.Timer
$timer.Interval = $DelaySeconds * 1000
$timer.AutoReset = $false

Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier AutoPushTimer -Action {
    if (-not $global:pending) { return }
    $global:pending = $false
    try {
        git add --all
        $status = git status --porcelain
        if ($status) {
            $msg = "${CommitPrefix} $(Get-Date -Format o)"
            git commit -m $msg
            git push
            Write-Host "Committed and pushed: $msg"
        }
    } catch {
        Write-Warning $_.Exception.Message
    }
}

$fsw = New-Object System.IO.FileSystemWatcher $Path -Property @{ 
    IncludeSubdirectories = $true
    NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, DirectoryName'
    Filter = '*.*'
}

$action = {
    $global:pending = $true
    $global:timer.Stop()
    $global:timer.Start()
}

Register-ObjectEvent -InputObject $fsw -EventName Changed -SourceIdentifier FSWChanged -Action $action
Register-ObjectEvent -InputObject $fsw -EventName Created -SourceIdentifier FSWCreated -Action $action
Register-ObjectEvent -InputObject $fsw -EventName Renamed -SourceIdentifier FSWRenamed -Action $action
Register-ObjectEvent -InputObject $fsw -EventName Deleted -SourceIdentifier FSWDeleted -Action $action

$fsw.EnableRaisingEvents = $true

Write-Host "Watching $Path for changes. Press Ctrl+C to stop."
while ($true) { Start-Sleep -Seconds 1 }
