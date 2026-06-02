Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── P/INVOKE TYPES — compiled once, cached to disk; subsequent launches skip the C# compiler ─
$_nativeCachePath = Join-Path $env:LOCALAPPDATA 'FlyMigration\NativeHelpers.dll'
$_nativeLoaded    = $false

if (Test-Path $_nativeCachePath) {
    try { [System.Reflection.Assembly]::LoadFrom($_nativeCachePath) | Out-Null; $_nativeLoaded = $true }
    catch { Remove-Item $_nativeCachePath -Force -ErrorAction SilentlyContinue }
}

if (-not $_nativeLoaded) {
    $_nativeDef = @'
using System; using System.Runtime.InteropServices;
namespace Win32 { public class DpiHelper {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); } }
namespace FlyConsole { public class NativeMethods {
    [DllImport("user32.dll")]   public static extern bool  ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool  AllowSetForegroundWindow(int dwProcessId); } }
namespace FlyMigration { public class Taskbar {
    [DllImport("shell32.dll")]
    public static extern int SetCurrentProcessExplicitAppUserModelID(
        [MarshalAs(UnmanagedType.LPWStr)] string AppID); } }
'@
    $_cacheDir = Split-Path $_nativeCachePath
    if (-not (Test-Path $_cacheDir)) { New-Item -ItemType Directory -Path $_cacheDir -Force | Out-Null }
    try   { Add-Type -TypeDefinition $_nativeDef -OutputAssembly $_nativeCachePath -ErrorAction Stop }
    catch { try { Add-Type -TypeDefinition $_nativeDef -ErrorAction SilentlyContinue } catch {} }
}

try { [Win32.DpiHelper]::SetProcessDPIAware() | Out-Null } catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()

try {
    $_consoleHwnd = [FlyConsole.NativeMethods]::GetConsoleWindow()
    if ($_consoleHwnd -ne [IntPtr]::Zero) {
        [FlyConsole.NativeMethods]::ShowWindow($_consoleHwnd, 0) | Out-Null  # SW_HIDE
    }
} catch {}

try { [FlyMigration.Taskbar]::SetCurrentProcessExplicitAppUserModelID('AvePoint.FlyMigration') | Out-Null } catch {}

# ── HIDDEN PROCESS LAUNCHER ───────────────────────────────────────────────────
# CREATE_NO_WINDOW prevents any console window being allocated for the child
# powershell.exe process. UseShellExecute=false with default (Normal) WindowStyle
# means STARTUPINFO.dwFlags does NOT include STARTF_USESHOWWINDOW, so the OS
# never applies an SW_HIDE override to the WinForms form's first ShowWindow call.
function Start-HiddenProcess {
    param([string]$Exe, [string]$Arguments)
    if (-not [System.IO.Path]::IsPathRooted($Exe)) {
        $cmd = Get-Command $Exe -ErrorAction SilentlyContinue
        if ($cmd) { $Exe = $cmd.Source }
    }
    $psi                  = New-Object System.Diagnostics.ProcessStartInfo($Exe)
    $psi.Arguments        = $Arguments
    $psi.UseShellExecute  = $false
    $psi.CreateNoWindow   = $true
    [System.Diagnostics.Process]::Start($psi) | Out-Null
}

# ── SHARED COLOURS & FONTS ────────────────────────────────────────────────────
$clrBg     = [System.Drawing.Color]::FromArgb(240, 242, 247)
$clrPanel  = [System.Drawing.Color]::White
$clrAccent = [System.Drawing.Color]::FromArgb(0, 100, 180)
$clrText   = [System.Drawing.Color]::FromArgb(28, 28, 32)
$clrMuted  = [System.Drawing.Color]::FromArgb(100, 108, 120)
$clrBorder = [System.Drawing.Color]::FromArgb(210, 215, 228)
$clrLogBg  = [System.Drawing.Color]::FromArgb(26, 27, 38)
$clrGrey   = [System.Drawing.Color]::FromArgb(175, 182, 195)
$clrGreen  = [System.Drawing.Color]::FromArgb(18, 155, 60)
$clrAmber  = [System.Drawing.Color]::FromArgb(195, 135, 0)
$clrRed    = [System.Drawing.Color]::FromArgb(195, 30, 30)

$FontBody  = New-Object System.Drawing.Font("Segoe UI", 9)
$FontBold  = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$FontCap   = New-Object System.Drawing.Font("Segoe UI Semibold", 7.5)
$FontMono  = New-Object System.Drawing.Font("Consolas", 8.5)
$FontTitle = New-Object System.Drawing.Font("Segoe UI Semibold", 14)

$AnchorTL  = [System.Windows.Forms.AnchorStyles]::Top  -bor [System.Windows.Forms.AnchorStyles]::Left
$AnchorTLR = [System.Windows.Forms.AnchorStyles]::Top  -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$AnchorTR  = [System.Windows.Forms.AnchorStyles]::Top  -bor [System.Windows.Forms.AnchorStyles]::Right

# ── GEAR BUTTON ICON ──────────────────────────────────────────────────────────
# Draw a white circle with the banner-blue gear inside — matches the circular
# settings icon style and sits correctly on the accent-coloured banner.
$script:GearBitmap = $null
try {
    $gSz  = 28   # bitmap size; button is 38x38 so this gives ~5px padding all round
    $gBmp = New-Object System.Drawing.Bitmap($gSz, $gSz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gGfx = [System.Drawing.Graphics]::FromImage($gBmp)
    $gGfx.SmoothingMode    = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gGfx.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $gGfx.Clear([System.Drawing.Color]::Transparent)

    # Filled white circle
    $gCircleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $gGfx.FillEllipse($gCircleBrush, 0, 0, $gSz - 1, $gSz - 1)
    $gCircleBrush.Dispose()

    # Banner-blue gear glyph centred inside the circle
    $gGearFont  = New-Object System.Drawing.Font("Segoe UI Symbol", 14, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $gGearBrush = New-Object System.Drawing.SolidBrush($clrAccent)
    $gSF = New-Object System.Drawing.StringFormat
    $gSF.Alignment     = [System.Drawing.StringAlignment]::Center
    $gSF.LineAlignment = [System.Drawing.StringAlignment]::Center
    $gGfx.DrawString([char]0x2699, $gGearFont, $gGearBrush, [System.Drawing.RectangleF]::new(0, 1, $gSz, $gSz), $gSF)
    $gGearFont.Dispose(); $gGearBrush.Dispose(); $gSF.Dispose()

    $gGfx.Dispose()
    $script:GearBitmap = $gBmp
} catch {}

# ── LOG ORGANIZATION ──────────────────────────────────────────────────────────
function Invoke-LogCleanup {
    <#
    .SYNOPSIS
        Organizes old log files into date-based folders
    .DESCRIPTION
        Moves log files older than today into 'Old\YYYY-MM-DD' subfolders.
        Keeps only today's logs in the root logs folder.
    #>
    param(
        [string]$LogDir = (Join-Path $PSScriptRoot 'logs')
    )

    if (-not (Test-Path $LogDir)) { return }

    try {
        $today = Get-Date -Format 'yyyy-MM-dd'
        $oldBaseDir = Join-Path $LogDir 'Old'

        # Get all log files and folders in the root logs directory
        $items = Get-ChildItem -Path $LogDir -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.Extension -in @('.log', '.html', '.png') }

        foreach ($item in $items) {
            # Extract date from filename (looking for yyyyMMdd or yyyy-MM-dd patterns)
            $fileDate = $null

            # Try yyyyMMdd format (e.g., main-menu-20260602-143022.log)
            if ($item.Name -match '(\d{8})') {
                $dateStr = $matches[1]
                try {
                    $fileDate = [DateTime]::ParseExact($dateStr, 'yyyyMMdd', $null)
                } catch { }
            }

            # Try yyyy-MM-dd format
            if (-not $fileDate -and $item.Name -match '(\d{4}-\d{2}-\d{2})') {
                $dateStr = $matches[1]
                try {
                    $fileDate = [DateTime]::Parse($dateStr)
                } catch { }
            }

            # If we couldn't parse date from filename, use file's LastWriteTime
            if (-not $fileDate) {
                $fileDate = $item.LastWriteTime
            }

            $fileDateStr = $fileDate.ToString('yyyy-MM-dd')

            # Move to Old folder if not today
            if ($fileDateStr -ne $today) {
                $targetDir = Join-Path $oldBaseDir $fileDateStr
                if (-not (Test-Path $targetDir)) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }

                $targetPath = Join-Path $targetDir $item.Name
                # If file already exists in target, append counter
                if (Test-Path $targetPath) {
                    $counter = 1
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($item.Name)
                    $ext = $item.Extension
                    while (Test-Path $targetPath) {
                        $targetPath = Join-Path $targetDir "$baseName-$counter$ext"
                        $counter++
                    }
                }

                Move-Item -Path $item.FullName -Destination $targetPath -Force -ErrorAction SilentlyContinue
            }
        }

        # Also organize subdirectories (like "login_2026-05-24_123917")
        $subDirs = Get-ChildItem -Path $LogDir -Directory -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -ne 'Old' }

        foreach ($dir in $subDirs) {
            # Extract date from directory name
            $dirDate = $null

            if ($dir.Name -match '(\d{4}-\d{2}-\d{2})') {
                $dateStr = $matches[1]
                try {
                    $dirDate = [DateTime]::Parse($dateStr)
                } catch { }
            } elseif ($dir.Name -match '(\d{8})') {
                $dateStr = $matches[1]
                try {
                    $dirDate = [DateTime]::ParseExact($dateStr, 'yyyyMMdd', $null)
                } catch { }
            }

            # Use directory's LastWriteTime if we can't parse date
            if (-not $dirDate) {
                $dirDate = $dir.LastWriteTime
            }

            $dirDateStr = $dirDate.ToString('yyyy-MM-dd')

            # Move to Old folder if not today
            if ($dirDateStr -ne $today) {
                $targetDir = Join-Path $oldBaseDir $dirDateStr
                if (-not (Test-Path $targetDir)) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }

                $targetPath = Join-Path $targetDir $dir.Name
                # If directory already exists, add counter
                if (Test-Path $targetPath) {
                    $counter = 1
                    while (Test-Path $targetPath) {
                        $targetPath = Join-Path $targetDir "$($dir.Name)-$counter"
                        $counter++
                    }
                }

                Move-Item -Path $dir.FullName -Destination $targetPath -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Silently ignore cleanup errors - don't want to break the main app
    }
}

# ── SHARED CONFIG ─────────────────────────────────────────────────────────────
$script:SharedConfigPath = Join-Path $env:LOCALAPPDATA "FlyMigration\shared-config.json"

function Read-SharedConfig {
    if (-not (Test-Path $script:SharedConfigPath)) { return [pscustomobject]@{} }
    try { return Get-Content $script:SharedConfigPath -Raw | ConvertFrom-Json }
    catch { return [pscustomobject]@{} }
}

function Update-SharedConfig {
    param([hashtable]$Values)
    $dir = Split-Path $script:SharedConfigPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $cfg = Read-SharedConfig
    foreach ($k in $Values.Keys) {
        if ($cfg.PSObject.Properties[$k]) { $cfg.$k = $Values[$k] }
        else { $cfg | Add-Member -NotePropertyName $k -NotePropertyValue $Values[$k] }
    }
    $cfg | ConvertTo-Json | Set-Content $script:SharedConfigPath -Encoding UTF8
}

# ── LOGO HELPER ───────────────────────────────────────────────────────────────
function Add-HeaderLogo {
    param($Header, [int]$LogoH = 34)
    $icoPath = Join-Path $PSScriptRoot "FlyMigration.ico"
    $pngPath = Join-Path $PSScriptRoot "ourvolaris.png"

    $img = $null
    if (Test-Path $icoPath) {
        try {
            # Read into a MemoryStream so the file isn't locked, then load at native
            # size (no size arg) to avoid the garbage-pixel bug when the ICO contains
            # a PNG-compressed 256x256 frame and a specific small size is requested.
            $bytes = [System.IO.File]::ReadAllBytes($icoPath)
            $ms    = New-Object System.IO.MemoryStream(,$bytes)
            $icon  = New-Object System.Drawing.Icon($ms)
            $raw   = $icon.ToBitmap()
            $icon.Dispose(); $ms.Dispose()
            # Scale to exactly LogoH x LogoH so the PictureBox never stretches it.
            $img = New-Object System.Drawing.Bitmap($LogoH, $LogoH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $gfx = [System.Drawing.Graphics]::FromImage($img)
            $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $gfx.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $gfx.Clear([System.Drawing.Color]::Transparent)
            $gfx.DrawImage($raw, 0, 0, $LogoH, $LogoH)
            $gfx.Dispose(); $raw.Dispose()
        } catch { $img = $null }
    }
    if (-not $img -and (Test-Path $pngPath)) {
        try {
            $raw  = [System.Drawing.Image]::FromFile($pngPath)
            $img  = New-Object System.Drawing.Bitmap($LogoH, $LogoH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $gfx  = [System.Drawing.Graphics]::FromImage($img)
            $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $gfx.Clear([System.Drawing.Color]::Transparent)
            $gfx.DrawImage($raw, 0, 0, $LogoH, $LogoH)
            $gfx.Dispose(); $raw.Dispose()
        } catch { $img = $null }
    }
    if (-not $img) { return 8 }

    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Image     = $img
    $pb.SizeMode  = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $pb.Size      = [System.Drawing.Size]::new($LogoH, $LogoH)
    $pb.BackColor = $clrAccent
    $pb.Anchor    = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $pb.Location  = [System.Drawing.Point]::new(8, [int](($Header.Height - $LogoH) / 2))
    $Header.Controls.Add($pb)
    return ($LogoH + 16)   # x-offset caller should use for the title label
}

# ── WINFORMS HELPERS (used by Migration Runner) ───────────────────────────────
function New-CardPanel {
    param($Title = "")
    $outer = New-Object System.Windows.Forms.Panel
    $outer.BackColor = $clrBorder
    $outer.Dock      = [System.Windows.Forms.DockStyle]::Fill
    $outer.Padding   = New-Object System.Windows.Forms.Padding(1)
    $inner = New-Object System.Windows.Forms.Panel
    $inner.BackColor = $clrPanel
    $inner.Dock      = [System.Windows.Forms.DockStyle]::Fill
    $outer.Controls.Add($inner)
    $bar = New-Object System.Windows.Forms.Panel
    $bar.BackColor = $clrAccent
    $bar.Width     = 4
    $bar.Dock      = [System.Windows.Forms.DockStyle]::Left
    $inner.Controls.Add($bar)
    if ($Title) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text      = $Title
        $lbl.Font      = $FontCap
        $lbl.ForeColor = $clrMuted
        $lbl.Location  = [System.Drawing.Point]::new(16, 9)
        $lbl.AutoSize  = $true
        $inner.Controls.Add($lbl)
    }
    return $inner
}

function New-Lbl {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [bool]$Bold = $false)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text; $l.Location = [System.Drawing.Point]::new($X, $Y)
    $l.AutoSize = $true; $l.Anchor = $AnchorTL
    $l.Font = if ($Bold) { $FontBold } else { $FontBody }
    $l.ForeColor = $clrText
    $Parent.Controls.Add($l)
    return $l
}

function New-TB {
    param($Parent, [int]$X, [int]$Y, [int]$W, [int]$RightMargin = -1,
          [bool]$Password = $false, [string]$Default = "")
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location    = [System.Drawing.Point]::new($X, $Y)
    $tb.Size        = [System.Drawing.Size]::new($W, 24)
    $tb.Font        = $FontBody
    $tb.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $tb.Text        = $Default
    if ($Password) { $tb.UseSystemPasswordChar = $true }
    if ($RightMargin -ge 0) {
        $tb.Anchor = $AnchorTLR
        $tb.Width  = $Parent.Width - $X - $RightMargin
    } else {
        $tb.Anchor = $AnchorTL
    }
    $Parent.Controls.Add($tb)
    return $tb
}

function New-Btn {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$W = 140, [int]$H = 30,
          [bool]$Primary = $true, [bool]$AnchorRight = $false)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text; $b.Location = [System.Drawing.Point]::new($X, $Y)
    $b.Size = [System.Drawing.Size]::new($W, $H); $b.Font = $FontBold
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = if ($Primary) { $clrAccent } else { [System.Drawing.Color]::FromArgb(225, 228, 238) }
    $b.ForeColor = if ($Primary) { [System.Drawing.Color]::White } else { $clrText }
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.Anchor    = if ($AnchorRight) { $AnchorTR } else { $AnchorTL }
    $Parent.Controls.Add($b)
    return $b
}

function New-Dot {
    param($Parent, [int]$X, [int]$Y)
    $d = New-Object System.Windows.Forms.Label
    $d.Text = [char]0x25CF; $d.Font = New-Object System.Drawing.Font("Segoe UI", 13)
    $d.ForeColor = $clrGrey; $d.Location = [System.Drawing.Point]::new($X, $Y)
    $d.AutoSize = $true; $d.Anchor = $AnchorTR
    $Parent.Controls.Add($d)
    return $d
}

function New-HSep {
    param($Parent, [int]$X, [int]$Y, [int]$RightMargin = 10)
    $s = New-Object System.Windows.Forms.Label
    $s.Location  = [System.Drawing.Point]::new($X, $Y)
    $s.Height    = 1
    $s.Width     = $Parent.Width - $X - $RightMargin
    $s.BackColor = $clrBorder
    $s.Anchor    = $AnchorTLR
    $Parent.Controls.Add($s)
}

# ── SHARED WRITE-LOG (App Reg overrides locally; Migration Runner uses this) ──
function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    if ($script:rtbLog -and -not $script:rtbLog.IsDisposed) {
        $script:rtbLog.SelectionStart  = $script:rtbLog.TextLength
        $script:rtbLog.SelectionLength = 0
        $script:rtbLog.SelectionColor  = [System.Drawing.Color]::FromArgb(80, 95, 120)
        $script:rtbLog.AppendText("$ts ")
        $levelColor = switch ($Level) {
            "OK"    { [System.Drawing.Color]::FromArgb(65, 195, 110) }
            "WARN"  { [System.Drawing.Color]::FromArgb(220, 165, 45) }
            "ERROR" { [System.Drawing.Color]::FromArgb(225, 80, 80) }
            default { [System.Drawing.Color]::FromArgb(120, 155, 220) }
        }
        $script:rtbLog.SelectionColor = $levelColor
        $script:rtbLog.AppendText("[$Level] ")
        $script:rtbLog.SelectionColor = [System.Drawing.Color]::FromArgb(205, 212, 230)
        $script:rtbLog.AppendText("$Msg`n")
        $script:rtbLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    if ($script:LogFile) { "$ts [$Level] $Msg" | Add-Content -Path $script:LogFile -Encoding UTF8 }
}

# ── WORKLOAD DEFINITIONS ───────────────────────────────────────────────────────
# Single authoritative source for AvePoint Fly cmdlet names per workload.
# runner.ps1 and monitor.ps1 both reference this via $script:FlyWorkloadDefs.
$script:FlyWorkloadDefs = [ordered]@{
    SharePoint   = @{ Import = 'Import-FlySharePointMappings';  Start = 'Start-FlySharePointMigration';  PreScan = 'Start-FlySharePointPreScan';  Verify = 'Start-FlySharePointVerification';  Status = 'Export-FlySharePointMappingStatus';  Report = 'Export-FlySharePointMigrationReport';  PolicyType = 'SharePoint' }
    Exchange     = @{ Import = 'Import-FlyExchangeMappings';    Start = 'Start-FlyExchangeMigration';    PreScan = 'Start-FlyExchangePreScan';    Verify = 'Start-FlyExchangeVerification';    Status = 'Export-FlyExchangeMappingStatus';    Report = 'Export-FlyExchangeMigrationReport';    PolicyType = 'Exchange'   }
    OneDrive     = @{ Import = 'Import-FlyOneDriveMappings';    Start = 'Start-FlyOneDriveMigration';    PreScan = 'Start-FlyOneDrivePreScan';    Verify = 'Start-FlyOneDriveVerification';    Status = 'Export-FlyOneDriveMappingStatus';    Report = 'Export-FlyOneDriveMigrationReport';    PolicyType = 'OneDrive'   }
    Teams        = @{ Import = 'Import-FlyTeamsMappings';       Start = 'Start-FlyTeamsMigration';       PreScan = 'Start-FlyTeamsPreScan';       Verify = 'Start-FlyTeamsVerification';       Status = 'Export-FlyTeamsMappingStatus';       Report = 'Export-FlyTeamsMigrationReport';       PolicyType = 'Teams'      }
    'Teams Chat' = @{ Import = 'Import-FlyTeamChatMappings';    Start = 'Start-FlyTeamChatMigration';    PreScan = '';                            Verify = 'Start-FlyTeamChatVerification';    Status = 'Export-FlyTeamChatMappingStatus';    Report = 'Export-FlyTeamChatMigrationReport';    PolicyType = 'TeamChat'   }
    Groups       = @{ Import = 'Import-FlyM365GroupMappings';   Start = 'Start-FlyM365GroupMigration';   PreScan = 'Start-FlyM365GroupPreScan';   Verify = 'Start-FlyM365GroupVerification';   Status = 'Export-FlyM365GroupMappingStatus';   Report = 'Export-FlyM365GroupMigrationReport';   PolicyType = 'M365Group'  }
}
