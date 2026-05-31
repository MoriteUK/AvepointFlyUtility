#Requires -Version 7.0
# VG Migrations — Top-Level Launcher

# Load WinForms early so we can show error dialogs if lib.ps1 is missing
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

# ── File logging — defined before dot-sourcing so startup errors are captured ─
$_logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $_logDir)) { New-Item -ItemType Directory -Path $_logDir -Force | Out-Null }
$script:LogFile = Join-Path $_logDir "main-menu-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')  [$($Level.PadRight(5))]  $Msg"
    Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}
Write-Log "=== main-menu.ps1 started  PID=$PID  PSVersion=$($PSVersionTable.PSVersion) ==="
Write-Log "Script root: $PSScriptRoot"

$_startupError = $null
try   { . "$PSScriptRoot\lib.ps1";      Write-Log 'lib.ps1 loaded OK' }
catch { $_startupError = "lib.ps1 failed to load: $($_.Exception.Message)"; Write-Log $_startupError 'ERROR' }

if ($_startupError) {
    [System.Windows.Forms.MessageBox]::Show(
        "$_startupError`n`nLog: $script:LogFile",
        'Startup Error', 'OK', 'Error') | Out-Null
    exit 1
}

try   { . "$PSScriptRoot\settings.ps1"; Write-Log 'settings.ps1 loaded OK' }
catch { Write-Log "settings.ps1 failed to load: $($_.Exception.Message)" 'WARN' }

# ── Discovery sub-menu ────────────────────────────────────────────────────────
function Show-DiscoverySubMenu {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text            = 'Discovery Tools'
    $dlg.ClientSize      = [System.Drawing.Size]::new(480, 280)
    $dlg.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.BackColor       = $clrBg
    $dlg.Font            = $FontBody
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $dlg.MaximizeBox     = $false
    $_ico = Join-Path $PSScriptRoot 'FlyMigration.ico'
    if (Test-Path $_ico) { $dlg.Icon = [System.Drawing.Icon]::new($_ico) }

    # ── Header ────────────────────────────────────────────────────────────────
    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(480, 56); $hdr.Dock = [System.Windows.Forms.DockStyle]::Top
    $hdr.BackColor = $clrAccent; $dlg.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 36
    $hdrLbl = New-Object System.Windows.Forms.Label
    $hdrLbl.Text      = '  Discovery Tools'
    $hdrLbl.Font      = $FontTitle
    $hdrLbl.ForeColor = [System.Drawing.Color]::White
    $hdrLbl.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrLbl.Size      = [System.Drawing.Size]::new(380, 56)
    $hdrLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdr.Controls.Add($hdrLbl)

    $btnGear = New-Object System.Windows.Forms.Button
    $btnGear.BackColor = $clrAccent; $btnGear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnGear.FlatAppearance.BorderSize = 0
    $btnGear.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 78, 152)
    $btnGear.Size = [System.Drawing.Size]::new(38, 38); $btnGear.Location = [System.Drawing.Point]::new(434, 9)
    $btnGear.Cursor = [System.Windows.Forms.Cursors]::Hand; $btnGear.Add_Click({ Show-SettingsDialog })
    if ($script:GearBitmap) { $btnGear.Image = $script:GearBitmap; $btnGear.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter }
    else { $btnGear.Text = [char]0x2699; $btnGear.Font = New-Object System.Drawing.Font('Segoe UI', 16); $btnGear.ForeColor = [System.Drawing.Color]::White }
    $hdr.Controls.Add($btnGear)

    $bW = 400; $bH = 90; $bX = 40; $y = 82

    # ── M365 Discovery ────────────────────────────────────────────────────────
    $btn1 = New-Object System.Windows.Forms.Button
    $btn1.Text      = 'M365 Discovery'
    $btn1.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btn1.Location  = [System.Drawing.Point]::new($bX, $y)
    $btn1.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btn1.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn1.FlatAppearance.BorderSize = 0
    $btn1.BackColor = $clrAccent
    $btn1.ForeColor = [System.Drawing.Color]::White
    $btn1.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $discScript = Join-Path $PSScriptRoot 'discovery-menu.ps1'
    $btn1.Add_Click({
        Write-Log "M365 Discovery clicked  path=$discScript"
        try   { [FlyConsole.NativeMethods]::AllowSetForegroundWindow(-1) | Out-Null } catch {}
        Write-Log "Launching discovery-menu: $discScript"
        try {
            Start-HiddenProcess 'pwsh.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$discScript`""
            Write-Log 'Launch returned'
            $dlg.Close()
        } catch {
            Write-Log "Discovery launch FAILED: $_" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show("Failed to launch:`n$_", 'Launch Error', 'OK', 'Error') | Out-Null
        }
    }.GetNewClosure())
    $dlg.Controls.Add($btn1)
    $y += $bH + 6

    $sub1 = New-Object System.Windows.Forms.Label
    $sub1.Text      = 'M365 tenant assessment — mailboxes, sites, OneDrive, groups, devices'
    $sub1.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sub1.ForeColor = $clrMuted
    $sub1.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $sub1.AutoSize  = $true
    $dlg.Controls.Add($sub1)

    $footer = New-Object System.Windows.Forms.Panel
    $footer.Height = 46; $footer.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footer.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 38)
    $dlg.Controls.Add($footer)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Close'; $btnClose.Size = [System.Drawing.Size]::new(90, 30)
    $btnClose.Location = [System.Drawing.Point]::new(374, 8)
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(200, 55, 55)
    $btnClose.ForeColor = [System.Drawing.Color]::White; $btnClose.Font = $FontBold
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
    $footer.Controls.Add($btnClose)
    $footer.Add_SizeChanged({ $btnClose.Left = $footer.Width - 100 }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
}

# ── Misc Scripts sub-menu ────────────────────────────────────────────────────
function Show-MiscSubMenu {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text            = 'Misc Scripts'
    $dlg.ClientSize      = [System.Drawing.Size]::new(480, 500)
    $dlg.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.BackColor       = $clrBg
    $dlg.Font            = $FontBody
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $dlg.MaximizeBox     = $false
    $_ico = Join-Path $PSScriptRoot 'FlyMigration.ico'
    if (Test-Path $_ico) { $dlg.Icon = [System.Drawing.Icon]::new($_ico) }

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(480, 56); $hdr.Dock = [System.Windows.Forms.DockStyle]::Top
    $hdr.BackColor = $clrAccent; $dlg.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 36
    $hdrLbl = New-Object System.Windows.Forms.Label
    $hdrLbl.Text      = '  Misc Scripts'
    $hdrLbl.Font      = $FontTitle
    $hdrLbl.ForeColor = [System.Drawing.Color]::White
    $hdrLbl.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrLbl.Size      = [System.Drawing.Size]::new(380, 56)
    $hdrLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdr.Controls.Add($hdrLbl)

    $btnGear = New-Object System.Windows.Forms.Button
    $btnGear.BackColor = $clrAccent; $btnGear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnGear.FlatAppearance.BorderSize = 0
    $btnGear.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 78, 152)
    $btnGear.Size = [System.Drawing.Size]::new(38, 38); $btnGear.Location = [System.Drawing.Point]::new(434, 9)
    $btnGear.Cursor = [System.Windows.Forms.Cursors]::Hand; $btnGear.Add_Click({ Show-SettingsDialog })
    if ($script:GearBitmap) { $btnGear.Image = $script:GearBitmap; $btnGear.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter }
    else { $btnGear.Text = [char]0x2699; $btnGear.Font = New-Object System.Drawing.Font('Segoe UI', 16); $btnGear.ForeColor = [System.Drawing.Color]::White }
    $hdr.Controls.Add($btnGear)

    $bW = 400; $bH = 90; $bX = 40; $y = 82

    # ── Provision OneDrives ───────────────────────────────────────────────────
    $miscScript1 = Join-Path $PSScriptRoot 'provision-onedrives.ps1'
    $miscBtn1 = New-Object System.Windows.Forms.Button
    $miscBtn1.Text      = 'Provision OneDrives'
    $miscBtn1.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $miscBtn1.Location  = [System.Drawing.Point]::new($bX, $y)
    $miscBtn1.Size      = [System.Drawing.Size]::new($bW, $bH)
    $miscBtn1.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $miscBtn1.FlatAppearance.BorderSize = 0
    $miscBtn1.BackColor = $clrAccent
    $miscBtn1.ForeColor = [System.Drawing.Color]::White
    $miscBtn1.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $miscBtn1.Add_Click({
        Write-Log "Provision OneDrives clicked  path=$miscScript1"
        if (-not (Test-Path $miscScript1)) {
            [System.Windows.Forms.MessageBox]::Show("Script not found:`n$miscScript1", 'Not Found', 'OK', 'Warning') | Out-Null; return
        }
        try   { [FlyConsole.NativeMethods]::AllowSetForegroundWindow(-1) | Out-Null } catch {}
        try {
            Start-HiddenProcess 'pwsh.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$miscScript1`""
            Write-Log 'Provision OneDrives launched'
        } catch {
            Write-Log "Provision OneDrives launch FAILED: $_" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show("Failed to launch:`n$_", 'Launch Error', 'OK', 'Error') | Out-Null
        }
    }.GetNewClosure())
    $dlg.Controls.Add($miscBtn1)
    $y += $bH + 6

    $miscSub1 = New-Object System.Windows.Forms.Label
    $miscSub1.Text      = 'Pre-provision OneDrive for Business sites from a mapping file'
    $miscSub1.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $miscSub1.ForeColor = $clrMuted
    $miscSub1.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $miscSub1.AutoSize  = $true
    $dlg.Controls.Add($miscSub1)
    $y += 26

    # ── Set Teams Owners ──────────────────────────────────────────────────────
    $miscScript2 = Join-Path $PSScriptRoot 'Set-TeamsOwners.ps1'
    $miscBtn2 = New-Object System.Windows.Forms.Button
    $miscBtn2.Text      = 'Set Teams Owners'
    $miscBtn2.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $miscBtn2.Location  = [System.Drawing.Point]::new($bX, $y)
    $miscBtn2.Size      = [System.Drawing.Size]::new($bW, $bH)
    $miscBtn2.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $miscBtn2.FlatAppearance.BorderSize = 0
    $miscBtn2.BackColor = $clrAccent
    $miscBtn2.ForeColor = [System.Drawing.Color]::White
    $miscBtn2.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $miscBtn2.Add_Click({
        Write-Log "Set Teams Owners clicked  path=$miscScript2"
        if (-not (Test-Path $miscScript2)) {
            [System.Windows.Forms.MessageBox]::Show("Script not found:`n$miscScript2", 'Not Found', 'OK', 'Warning') | Out-Null; return
        }
        try   { [FlyConsole.NativeMethods]::AllowSetForegroundWindow(-1) | Out-Null } catch {}
        try {
            Start-HiddenProcess 'pwsh.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$miscScript2`""
            Write-Log 'Set Teams Owners launched'
        } catch {
            Write-Log "Set Teams Owners launch FAILED: $_" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show("Failed to launch:`n$_", 'Launch Error', 'OK', 'Error') | Out-Null
        }
    }.GetNewClosure())
    $dlg.Controls.Add($miscBtn2)
    $y += $bH + 6

    $miscSub2 = New-Object System.Windows.Forms.Label
    $miscSub2.Text      = 'Add a user as owner to Teams and M365 Groups from a CSV'
    $miscSub2.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $miscSub2.ForeColor = $clrMuted
    $miscSub2.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $miscSub2.AutoSize  = $true
    $dlg.Controls.Add($miscSub2)
    $y += 26

    $dlg.ClientSize = [System.Drawing.Size]::new(480, ($y + 56))

    $footer = New-Object System.Windows.Forms.Panel
    $footer.Height = 46; $footer.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footer.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 38)
    $dlg.Controls.Add($footer)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Close'; $btnClose.Size = [System.Drawing.Size]::new(90, 30)
    $btnClose.Location = [System.Drawing.Point]::new(374, 8)
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(200, 55, 55)
    $btnClose.ForeColor = [System.Drawing.Color]::White; $btnClose.Font = $FontBold
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
    $footer.Controls.Add($btnClose)
    $footer.Add_SizeChanged({ $btnClose.Left = $footer.Width - 100 }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
}

# ── Domain Removal sub-menu ───────────────────────────────────────────────────
function Show-DomainRemovalSubMenu {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text            = 'Domain Removal'
    $dlg.ClientSize      = [System.Drawing.Size]::new(480, 390)
    $dlg.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.BackColor       = $clrBg
    $dlg.Font            = $FontBody
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $dlg.MaximizeBox     = $false
    $_ico = Join-Path $PSScriptRoot 'FlyMigration.ico'
    if (Test-Path $_ico) { $dlg.Icon = [System.Drawing.Icon]::new($_ico) }

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(480, 56); $hdr.Dock = [System.Windows.Forms.DockStyle]::Top
    $hdr.BackColor = $clrAccent; $dlg.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 36
    $hdrLbl = New-Object System.Windows.Forms.Label
    $hdrLbl.Text      = '  Domain Removal'
    $hdrLbl.Font      = $FontTitle
    $hdrLbl.ForeColor = [System.Drawing.Color]::White
    $hdrLbl.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrLbl.Size      = [System.Drawing.Size]::new(380, 56)
    $hdrLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdr.Controls.Add($hdrLbl)

    $btnGear = New-Object System.Windows.Forms.Button
    $btnGear.BackColor = $clrAccent; $btnGear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnGear.FlatAppearance.BorderSize = 0
    $btnGear.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 78, 152)
    $btnGear.Size = [System.Drawing.Size]::new(38, 38); $btnGear.Location = [System.Drawing.Point]::new(434, 9)
    $btnGear.Cursor = [System.Windows.Forms.Cursors]::Hand; $btnGear.Add_Click({ Show-SettingsDialog })
    if ($script:GearBitmap) { $btnGear.Image = $script:GearBitmap; $btnGear.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter }
    else { $btnGear.Text = [char]0x2699; $btnGear.Font = New-Object System.Drawing.Font('Segoe UI', 16); $btnGear.ForeColor = [System.Drawing.Color]::White }
    $hdr.Controls.Add($btnGear)

    $bW = 400; $bH = 90; $bX = 40; $y = 82

    # ── Remove Devices ────────────────────────────────────────────────────────
    $script1 = Join-Path $PSScriptRoot 'Remove-devices.ps1'
    $btn1 = New-Object System.Windows.Forms.Button
    $btn1.Text      = 'Remove Devices'
    $btn1.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btn1.Location  = [System.Drawing.Point]::new($bX, $y)
    $btn1.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btn1.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn1.FlatAppearance.BorderSize = 0
    $btn1.BackColor = $clrAccent
    $btn1.ForeColor = [System.Drawing.Color]::White
    $btn1.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btn1.Add_Click({
        Write-Log "Remove Devices clicked  path=$script1"
        if (-not (Test-Path $script1)) {
            [System.Windows.Forms.MessageBox]::Show("Script not found:`n$script1", 'Not Found', 'OK', 'Warning') | Out-Null; return
        }
        try   { [FlyConsole.NativeMethods]::AllowSetForegroundWindow(-1) | Out-Null } catch {}
        try {
            Start-HiddenProcess 'pwsh.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$script1`""
            Write-Log 'Remove Devices launched'
        } catch {
            Write-Log "Remove Devices launch FAILED: $_" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show("Failed to launch:`n$_", 'Launch Error', 'OK', 'Error') | Out-Null
        }
    }.GetNewClosure())
    $dlg.Controls.Add($btn1)
    $y += $bH + 6

    $sub1 = New-Object System.Windows.Forms.Label
    $sub1.Text      = 'Remove Entra ID / Intune registered devices from the tenant'
    $sub1.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sub1.ForeColor = $clrMuted
    $sub1.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $sub1.AutoSize  = $true
    $dlg.Controls.Add($sub1)
    $y += 26

    # ── Remove Domain ─────────────────────────────────────────────────────────
    $script2 = Join-Path $PSScriptRoot 'remove-domain.ps1'
    $btn2 = New-Object System.Windows.Forms.Button
    $btn2.Text      = 'Remove Domain'
    $btn2.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btn2.Location  = [System.Drawing.Point]::new($bX, $y)
    $btn2.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btn2.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn2.FlatAppearance.BorderSize = 0
    $btn2.BackColor = $clrAccent
    $btn2.ForeColor = [System.Drawing.Color]::White
    $btn2.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btn2.Add_Click({
        Write-Log "Remove Domain clicked  path=$script2"
        if (-not (Test-Path $script2)) {
            [System.Windows.Forms.MessageBox]::Show("Script not found:`n$script2", 'Not Found', 'OK', 'Warning') | Out-Null; return
        }
        try   { [FlyConsole.NativeMethods]::AllowSetForegroundWindow(-1) | Out-Null } catch {}
        try {
            Start-HiddenProcess 'pwsh.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$script2`""
            Write-Log 'Remove Domain launched'
        } catch {
            Write-Log "Remove Domain launch FAILED: $_" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show("Failed to launch:`n$_", 'Launch Error', 'OK', 'Error') | Out-Null
        }
    }.GetNewClosure())
    $dlg.Controls.Add($btn2)
    $y += $bH + 6

    $sub2 = New-Object System.Windows.Forms.Label
    $sub2.Text      = 'Remove a verified domain and all associated M365 objects'
    $sub2.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sub2.ForeColor = $clrMuted
    $sub2.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $sub2.AutoSize  = $true
    $dlg.Controls.Add($sub2)
    $y += 26

    # ── Update UPNs ───────────────────────────────────────────────────────────
    $domScript3 = Join-Path $PSScriptRoot 'Update-UPN.ps1'
    $domBtn3 = New-Object System.Windows.Forms.Button
    $domBtn3.Text      = 'Update UPNs'
    $domBtn3.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $domBtn3.Location  = [System.Drawing.Point]::new($bX, $y)
    $domBtn3.Size      = [System.Drawing.Size]::new($bW, $bH)
    $domBtn3.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $domBtn3.FlatAppearance.BorderSize = 0
    $domBtn3.BackColor = $clrAccent
    $domBtn3.ForeColor = [System.Drawing.Color]::White
    $domBtn3.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $domBtn3.Add_Click({
        Write-Log "Update UPNs clicked  path=$domScript3"
        if (-not (Test-Path $domScript3)) {
            [System.Windows.Forms.MessageBox]::Show("Script not found:`n$domScript3", 'Not Found', 'OK', 'Warning') | Out-Null; return
        }
        try { [FlyConsole.NativeMethods]::AllowSetForegroundWindow(-1) | Out-Null } catch {}
        try {
            Start-HiddenProcess 'pwsh.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$domScript3`""
            Write-Log 'Update UPNs launched'
        } catch {
            Write-Log "Update UPNs launch FAILED: $_" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show("Failed to launch:`n$_", 'Launch Error', 'OK', 'Error') | Out-Null
        }
    }.GetNewClosure())
    $dlg.Controls.Add($domBtn3)
    $y += $bH + 6

    $domSub3 = New-Object System.Windows.Forms.Label
    $domSub3.Text      = 'Change UPN domain suffix for all users matching a source domain'
    $domSub3.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $domSub3.ForeColor = $clrMuted
    $domSub3.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $domSub3.AutoSize  = $true
    $dlg.Controls.Add($domSub3)
    $y += 26

    # ── Hide from Address Book ────────────────────────────────────────────────
    $domScript4 = Join-Path $PSScriptRoot 'Hide-AddressBook.ps1'
    $domBtn4 = New-Object System.Windows.Forms.Button
    $domBtn4.Text      = 'Hide from Address Book'
    $domBtn4.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $domBtn4.Location  = [System.Drawing.Point]::new($bX, $y)
    $domBtn4.Size      = [System.Drawing.Size]::new($bW, $bH)
    $domBtn4.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $domBtn4.FlatAppearance.BorderSize = 0
    $domBtn4.BackColor = $clrAccent
    $domBtn4.ForeColor = [System.Drawing.Color]::White
    $domBtn4.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $domBtn4.Add_Click({
        Write-Log "Hide from Address Book clicked  path=$domScript4"
        if (-not (Test-Path $domScript4)) {
            [System.Windows.Forms.MessageBox]::Show("Script not found:`n$domScript4", 'Not Found', 'OK', 'Warning') | Out-Null; return
        }
        try { [FlyConsole.NativeMethods]::AllowSetForegroundWindow(-1) | Out-Null } catch {}
        try {
            Start-HiddenProcess 'pwsh.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$domScript4`""
            Write-Log 'Hide from Address Book launched'
        } catch {
            Write-Log "Hide from Address Book launch FAILED: $_" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show("Failed to launch:`n$_", 'Launch Error', 'OK', 'Error') | Out-Null
        }
    }.GetNewClosure())
    $dlg.Controls.Add($domBtn4)
    $y += $bH + 6

    $domSub4 = New-Object System.Windows.Forms.Label
    $domSub4.Text      = 'Bulk hide Exchange Online recipients from the Global Address List'
    $domSub4.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $domSub4.ForeColor = $clrMuted
    $domSub4.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $domSub4.AutoSize  = $true
    $dlg.Controls.Add($domSub4)
    $y += 26

    $dlg.ClientSize = [System.Drawing.Size]::new(480, ($y + 56))

    $footer = New-Object System.Windows.Forms.Panel
    $footer.Height = 46; $footer.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footer.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 38)
    $dlg.Controls.Add($footer)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Close'; $btnClose.Size = [System.Drawing.Size]::new(90, 30)
    $btnClose.Location = [System.Drawing.Point]::new(374, 8)
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(200, 55, 55)
    $btnClose.ForeColor = [System.Drawing.Color]::White; $btnClose.Font = $FontBold
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
    $footer.Controls.Add($btnClose)
    $footer.Add_SizeChanged({ $btnClose.Left = $footer.Width - 100 }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
}

# ── Main launcher ─────────────────────────────────────────────────────────────
function Show-Launcher {
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'VG Migration Tools'
    $form.ClientSize      = [System.Drawing.Size]::new(480, 620)
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.BackColor       = $clrBg
    $form.Font            = $FontBody
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox     = $false
    $_ico = Join-Path $PSScriptRoot 'FlyMigration.ico'
    if (Test-Path $_ico) { $form.Icon = [System.Drawing.Icon]::new($_ico) }

    # ── Header ────────────────────────────────────────────────────────────────
    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(480, 56)
    $hdr.Dock = [System.Windows.Forms.DockStyle]::Top
    $hdr.BackColor = $clrAccent
    $form.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 36
    $hdrLbl = New-Object System.Windows.Forms.Label
    $hdrLbl.Text      = '  VG Migration Tools'
    $hdrLbl.Font      = $FontTitle
    $hdrLbl.ForeColor = [System.Drawing.Color]::White
    $hdrLbl.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrLbl.Size      = [System.Drawing.Size]::new(380, 56)
    $hdrLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdr.Controls.Add($hdrLbl)

    $btnGear = New-Object System.Windows.Forms.Button
    $btnGear.BackColor = $clrAccent; $btnGear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnGear.FlatAppearance.BorderSize = 0
    $btnGear.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 78, 152)
    $btnGear.Size = [System.Drawing.Size]::new(38, 38); $btnGear.Location = [System.Drawing.Point]::new(434, 9)
    $btnGear.Cursor = [System.Windows.Forms.Cursors]::Hand; $btnGear.Add_Click({ Show-SettingsDialog })
    if ($script:GearBitmap) { $btnGear.Image = $script:GearBitmap; $btnGear.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter }
    else { $btnGear.Text = [char]0x2699; $btnGear.Font = New-Object System.Drawing.Font('Segoe UI', 16); $btnGear.ForeColor = [System.Drawing.Color]::White }
    $hdr.Controls.Add($btnGear)

    $bW = 400; $bH = 90; $bX = 40; $y = 82

    # ── Discovery tile ────────────────────────────────────────────────────────
    $btnDisc = New-Object System.Windows.Forms.Button
    $btnDisc.Text      = 'Discovery'
    $btnDisc.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btnDisc.Location  = [System.Drawing.Point]::new($bX, $y)
    $btnDisc.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btnDisc.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDisc.FlatAppearance.BorderSize = 0
    $btnDisc.BackColor = $clrAccent
    $btnDisc.ForeColor = [System.Drawing.Color]::White
    $btnDisc.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btnDisc.Add_Click({
        Write-Log 'Discovery tile clicked — opening sub-menu'
        Show-DiscoverySubMenu
        Write-Log 'Discovery sub-menu closed'
    }.GetNewClosure())
    $form.Controls.Add($btnDisc)
    $y += $bH + 6

    $lblDiscSub = New-Object System.Windows.Forms.Label
    $lblDiscSub.Text      = 'M365 tenant assessment — mailboxes, sites, OneDrive, groups'
    $lblDiscSub.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $lblDiscSub.ForeColor = $clrMuted
    $lblDiscSub.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $lblDiscSub.AutoSize  = $true
    $form.Controls.Add($lblDiscSub)
    $y += 26

    # ── AvePoint Fly tile ─────────────────────────────────────────────────────
    $btnAve = New-Object System.Windows.Forms.Button
    $btnAve.Text      = 'AvePoint Fly'
    $btnAve.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btnAve.Location  = [System.Drawing.Point]::new($bX, $y)
    $btnAve.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btnAve.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnAve.FlatAppearance.BorderSize = 0
    $btnAve.BackColor = $clrAccent
    $btnAve.ForeColor = [System.Drawing.Color]::White
    $btnAve.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $menuScript = Join-Path $PSScriptRoot 'menu.ps1'
    $btnAve.Add_Click({
        Write-Log "AvePoint Fly clicked  path=$menuScript"
        try   { [FlyConsole.NativeMethods]::AllowSetForegroundWindow(-1) | Out-Null } catch {}
        Write-Log "Launching menu: $menuScript"
        try {
            Start-HiddenProcess 'pwsh.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$menuScript`""
            Write-Log 'Launch returned'
        } catch {
            Write-Log "AvePoint Fly launch FAILED: $_" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show("Failed to launch:`n$_", 'Launch Error', 'OK', 'Error') | Out-Null
        }
    }.GetNewClosure())
    $form.Controls.Add($btnAve)
    $y += $bH + 6

    $lblAveSub = New-Object System.Windows.Forms.Label
    $lblAveSub.Text      = 'Migration toolkit — connections, mappings, monitoring'
    $lblAveSub.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $lblAveSub.ForeColor = $clrMuted
    $lblAveSub.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $lblAveSub.AutoSize  = $true
    $form.Controls.Add($lblAveSub)
    $y += 26

    # ── Misc Scripts tile ─────────────────────────────────────────────────────
    $btnMisc = New-Object System.Windows.Forms.Button
    $btnMisc.Text      = 'Misc Scripts'
    $btnMisc.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btnMisc.Location  = [System.Drawing.Point]::new($bX, $y)
    $btnMisc.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btnMisc.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMisc.FlatAppearance.BorderSize = 0
    $btnMisc.BackColor = $clrAccent
    $btnMisc.ForeColor = [System.Drawing.Color]::White
    $btnMisc.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btnMisc.Add_Click({
        Write-Log 'Misc Scripts tile clicked — opening sub-menu'
        Show-MiscSubMenu
        Write-Log 'Misc Scripts sub-menu closed'
    }.GetNewClosure())
    $form.Controls.Add($btnMisc)
    $y += $bH + 6

    $lblMiscSub = New-Object System.Windows.Forms.Label
    $lblMiscSub.Text      = 'Utility and helper scripts'
    $lblMiscSub.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $lblMiscSub.ForeColor = $clrMuted
    $lblMiscSub.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $lblMiscSub.AutoSize  = $true
    $form.Controls.Add($lblMiscSub)
    $y += 26

    # ── Domain Removal tile ───────────────────────────────────────────────────
    $btnDom = New-Object System.Windows.Forms.Button
    $btnDom.Text      = 'Domain Removal'
    $btnDom.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btnDom.Location  = [System.Drawing.Point]::new($bX, $y)
    $btnDom.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btnDom.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDom.FlatAppearance.BorderSize = 0
    $btnDom.BackColor = $clrAccent
    $btnDom.ForeColor = [System.Drawing.Color]::White
    $btnDom.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btnDom.Add_Click({
        Write-Log 'Domain Removal tile clicked — opening sub-menu'
        Show-DomainRemovalSubMenu
        Write-Log 'Domain Removal sub-menu closed'
    }.GetNewClosure())
    $form.Controls.Add($btnDom)
    $y += $bH + 6

    $lblDomSub = New-Object System.Windows.Forms.Label
    $lblDomSub.Text      = 'Scripts for removing and cleaning up domains'
    $lblDomSub.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $lblDomSub.ForeColor = $clrMuted
    $lblDomSub.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $lblDomSub.AutoSize  = $true
    $form.Controls.Add($lblDomSub)

    $footer = New-Object System.Windows.Forms.Panel
    $footer.Height = 46; $footer.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footer.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 38)
    $form.Controls.Add($footer)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Close'; $btnClose.Size = [System.Drawing.Size]::new(90, 30)
    $btnClose.Location = [System.Drawing.Point]::new(374, 8)
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(200, 55, 55)
    $btnClose.ForeColor = [System.Drawing.Color]::White; $btnClose.Font = $FontBold
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.Add_Click({ $form.Close() }.GetNewClosure())
    $footer.Controls.Add($btnClose)
    $footer.Add_SizeChanged({ $btnClose.Left = $footer.Width - 100 }.GetNewClosure())

    $form.Add_FormClosed({ Write-Log '=== Launcher closed ===' }.GetNewClosure())

    Write-Log 'Launcher form ready — entering Application::Run'
    try {
        [System.Windows.Forms.Application]::Run($form)
    } catch {
        Write-Log "Application::Run crashed: $($_.Exception.Message)" 'ERROR'
        Write-Log "  $($_.ScriptStackTrace)" 'ERROR'
        [System.Windows.Forms.MessageBox]::Show(
            "Fatal error launching the main window:`n$($_.Exception.Message)`n`nLog: $script:LogFile",
            'Fatal Error', 'OK', 'Error') | Out-Null
    }
}

# ── Check for Updates ─────────────────────────────────────────────────────────
$CheckUpdatesScript = Join-Path $PSScriptRoot 'Check-Updates.ps1'
if (Test-Path $CheckUpdatesScript) {
    try {
        Write-Log 'Checking for updates...'
        # Run update check silently in background (won't block startup)
        $null = Start-Job -ScriptBlock {
            param($ScriptPath)
            & $ScriptPath -Silent
        } -ArgumentList $CheckUpdatesScript

        # Don't wait for update check - let it run in background
        Write-Log 'Update check started in background'
    } catch {
        Write-Log "Update check failed to start: $($_.Exception.Message)" 'WARN'
    }
}

Write-Log 'Calling Show-Launcher'

# Must be set before any controls are created (i.e. before Show-Launcher instantiates the Form)
[System.Windows.Forms.Application]::SetUnhandledExceptionMode(
    [System.Windows.Forms.UnhandledExceptionMode]::CatchException)
[System.Windows.Forms.Application]::add_ThreadException({
    param($s, $e)
    Write-Log "UNHANDLED UI EXCEPTION: $($e.Exception.Message)" 'ERROR'
    Write-Log "  $($e.Exception.StackTrace -replace [Environment]::NewLine,' | ')" 'ERROR'
    [System.Windows.Forms.MessageBox]::Show(
        "An unexpected error occurred:`n$($e.Exception.Message)`n`nSee log for details:`n$script:LogFile",
        'Error', 'OK', 'Error') | Out-Null
})

try {
    Show-Launcher
} catch {
    Write-Log "Show-Launcher crashed: $($_.Exception.Message)" 'ERROR'
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to start:`n$($_.Exception.Message)`n`nLog: $script:LogFile",
        'Startup Failure', 'OK', 'Error') | Out-Null
}
Write-Log '=== main-menu.ps1 exiting ==='
