#Requires -Version 5.1
<#
.SYNOPSIS
    Creates a distributable ZIP of the Fly Migration Tools ready for a new user to install.

.PARAMETER Version
    Version string to embed in the ZIP filename, e.g. "1.0", "1.2.3".
    If omitted, the script scans the output directory for existing
    FlyMigrationTools_v*.zip files and auto-increments the highest version found.
    Falls back to "1.0" if no prior package exists.

.PARAMETER OutputPath
    Full path (including filename) for the ZIP file.
    Defaults to the AvePoint scripts folder in the Volaris OneDrive.

.EXAMPLE
    .\New-Package.ps1                                  # auto-bumps version
    .\New-Package.ps1 -Version "1.2"                   # forces a version
    .\New-Package.ps1 -OutputPath "C:\Releases\X.zip"  # custom path
#>

[CmdletBinding()]
param(
    [string]$Version    = '',
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

$defaultDir = 'C:\Users\Andy White\Volaris Group\GRP Data Security (Volaris Consolidated) - M365 Migrations\Scripts\Avepoint'

function Write-Step($message) { Write-Host "`n==> $message" -ForegroundColor Cyan }
function Write-Ok  ($message) { Write-Host "    [OK]   $message" -ForegroundColor Green }
function Write-Warn($message) { Write-Host "    [WARN] $message" -ForegroundColor Yellow }

# -----------------------------------------------------------------------
# Auto-bump version if caller didn't specify one
# -----------------------------------------------------------------------
if (-not $Version) {
    $highest = $null
    if (Test-Path $defaultDir) {
        $highest = Get-ChildItem -Path $defaultDir -Filter 'FlyMigrationTools_v*.zip' -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($_.BaseName -match '^FlyMigrationTools_v(\d+(?:\.\d+)+)$') { [version]$matches[1] }
            } | Sort-Object -Descending | Select-Object -First 1
    }
    if ($highest) {
        $parts = $highest.ToString().Split('.')
        $parts[-1] = [int]$parts[-1] + 1
        $Version = $parts -join '.'
        Write-Host "Auto-bumped version: $highest -> $Version" -ForegroundColor Yellow
    } else {
        $Version = '1.0'
        Write-Host "No prior package found - starting at v$Version" -ForegroundColor Yellow
    }
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $defaultDir "FlyMigrationTools_v$Version.zip"
}

$src = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$files = @(
    'FlyMigration.exe'        # no-console launcher – double-click entry point
    'FlyMigration.ico'        # icon used by the launcher and all banner headers
    'menu.ps1'
    'fly-connector.js'
    'package.json'
    'install-flymodules.ps1'
    'Setup.ps1'
    'Setup.cmd'
    'README.md'
)

# Clean workloads template - tenant-specific values stripped so the new user starts fresh
$workloadsTemplate = [ordered]@{
    SharePoint   = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
    Exchange     = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
    OneDrive     = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
    Teams        = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
    'Teams Chat' = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
    Groups       = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
}

# -----------------------------------------------------------------------
Write-Step "Building package v$Version from: $src"

$tmp = Join-Path $env:TEMP "FlyMigrationTools_$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    $missing = [System.Collections.Generic.List[string]]::new()

    foreach ($f in $files) {
        $srcPath = Join-Path $src $f
        if (Test-Path $srcPath) {
            Copy-Item $srcPath -Destination $tmp
            Write-Ok "Included: $f"
        } else {
            $missing.Add($f)
            Write-Warn "Not found (excluded): $f"
        }
    }

    $workloadsTemplate | ConvertTo-Json -Depth 3 |
        Set-Content (Join-Path $tmp 'workloads.json') -Encoding UTF8
    Write-Ok "Included: workloads.json  (blank template - tenant values stripped)"

    # -----------------------------------------------------------------------
    Write-Step "Creating ZIP"

    $outDir = Split-Path $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $OutputPath)

    $sizeKB = [math]::Round((Get-Item $OutputPath).Length / 1KB)
    Write-Ok "Created: $OutputPath  ($sizeKB KB)"

    if ($missing.Count -gt 0) {
        Write-Warn "The following files were not found and were excluded:"
        $missing | ForEach-Object { Write-Warn "  - $_" }
    }

    # -----------------------------------------------------------------------
    Write-Step "Done"
    Write-Host ""
    Write-Host "    Unzip to any folder, then:" -ForegroundColor White
    Write-Host "      1. Run Setup.cmd once to install Node.js, npm packages, and Playwright." -ForegroundColor Gray
    Write-Host "      2. Double-click FlyMigration.exe to launch the toolkit." -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Before running migrations, edit workloads.json to add:" -ForegroundColor White
    Write-Host "        - Policy names (from their Fly environment)" -ForegroundColor Gray
    Write-Host "        - Source connection names" -ForegroundColor Gray
    Write-Host "        - Destination connection names (use the Connections screen to create them)" -ForegroundColor Gray
    Write-Host ""

    Start-Process explorer.exe "/select,`"$OutputPath`""

} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}