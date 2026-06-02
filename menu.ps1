#Requires -Version 7.0
# Migration Toolkit - Entry Point

. "$PSScriptRoot\lib.ps1"
Invoke-LogCleanup  # Organize old logs into date-based folders
. "$PSScriptRoot\settings.ps1"
. "$PSScriptRoot\appregistration.ps1"
. "$PSScriptRoot\aossetup.ps1"
. "$PSScriptRoot\runner.ps1"
. "$PSScriptRoot\monitor.ps1"
. "$PSScriptRoot\reports.ps1"

function Show-MainMenu {
    $MenuForm = New-Object System.Windows.Forms.Form
    $MenuForm.Text            = "AvePoint Fly - Migration Toolkit"
    $MenuForm.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $MenuForm.BackColor       = $clrBg
    $MenuForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $MenuForm.MaximizeBox     = $false
    $MenuForm.Font            = $FontBody
    $_ico = Join-Path $PSScriptRoot 'FlyMigration.ico'; if (Test-Path $_ico) { $MenuForm.Icon = [System.Drawing.Icon]::new($_ico) }

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(480, 56); $hdr.Dock = [System.Windows.Forms.DockStyle]::Top; $hdr.BackColor = $clrAccent
    $MenuForm.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 40
    $hdrTitle = New-Object System.Windows.Forms.Label
    $hdrTitle.Text      = "  Migration Toolkit"
    $hdrTitle.Font      = $FontTitle
    $hdrTitle.ForeColor = [System.Drawing.Color]::White
    $hdrTitle.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrTitle.Size      = [System.Drawing.Size]::new(380, 56)
    $hdrTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdr.Controls.Add($hdrTitle)

    $btnGear = New-Object System.Windows.Forms.Button
    $btnGear.BackColor = $clrAccent
    $btnGear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnGear.FlatAppearance.BorderSize = 0
    $btnGear.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 78, 152)
    $btnGear.Size     = [System.Drawing.Size]::new(38, 38)
    $btnGear.Location = [System.Drawing.Point]::new(434, 9)
    $btnGear.Cursor   = [System.Windows.Forms.Cursors]::Hand
    $btnGear.Add_Click({ Show-SettingsDialog })
    if ($script:GearBitmap) {
        $btnGear.Image = $script:GearBitmap; $btnGear.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    } else {
        $btnGear.Text = [char]0x2699; $btnGear.Font = New-Object System.Drawing.Font("Segoe UI", 16)
        $btnGear.ForeColor = [System.Drawing.Color]::White
    }
    $hdr.Controls.Add($btnGear)

    $bW = 400; $bH = 90; $bX = 40; $y = 82

    # ── 1. Create App Registration ────────────────────────────────────────────
    $btn1 = New-Object System.Windows.Forms.Button
    $btn1.Text      = "1. Create App Registration"
    $btn1.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btn1.Location  = [System.Drawing.Point]::new($bX, $y)
    $btn1.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btn1.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn1.FlatAppearance.BorderSize = 0; $btn1.BackColor = $clrAccent
    $btn1.ForeColor = [System.Drawing.Color]::White; $btn1.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn1)
    $y += $bH + 6

    $sub1 = New-Object System.Windows.Forms.Label
    $sub1.Text      = 'Register the Entra ID app and grant required API permissions'
    $sub1.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sub1.ForeColor = $clrMuted
    $sub1.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $sub1.AutoSize  = $true
    $MenuForm.Controls.Add($sub1)
    $y += 26

    # ── 2. Setup AOS Tenant & App ─────────────────────────────────────────────
    $btn2 = New-Object System.Windows.Forms.Button
    $btn2.Text      = "2. Setup AOS Tenant & App"
    $btn2.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btn2.Location  = [System.Drawing.Point]::new($bX, $y)
    $btn2.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btn2.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn2.FlatAppearance.BorderSize = 0; $btn2.BackColor = $clrAccent
    $btn2.ForeColor = [System.Drawing.Color]::White; $btn2.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn2)
    $y += $bH + 6

    $sub2 = New-Object System.Windows.Forms.Label
    $sub2.Text      = 'Configure the AvePoint Online Services tenant and application'
    $sub2.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sub2.ForeColor = $clrMuted
    $sub2.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $sub2.AutoSize  = $true
    $MenuForm.Controls.Add($sub2)
    $y += 26

    # ── 3. Connections & Migration Mappings ───────────────────────────────────
    $btn3 = New-Object System.Windows.Forms.Button
    $btn3.Text      = "3. Connections & Migration Mappings"
    $btn3.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btn3.Location  = [System.Drawing.Point]::new($bX, $y)
    $btn3.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btn3.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn3.FlatAppearance.BorderSize = 0; $btn3.BackColor = $clrAccent
    $btn3.ForeColor = [System.Drawing.Color]::White; $btn3.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn3)
    $y += $bH + 6

    $sub3 = New-Object System.Windows.Forms.Label
    $sub3.Text      = 'Manage connections, source/destination accounts and job mappings'
    $sub3.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sub3.ForeColor = $clrMuted
    $sub3.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $sub3.AutoSize  = $true
    $MenuForm.Controls.Add($sub3)
    $y += 26

    # ── 4. View Migration Reports ─────────────────────────────────────────────
    $btn4 = New-Object System.Windows.Forms.Button
    $btn4.Text      = "4. View Migration Reports"
    $btn4.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btn4.Location  = [System.Drawing.Point]::new($bX, $y)
    $btn4.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btn4.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn4.FlatAppearance.BorderSize = 0; $btn4.BackColor = $clrAccent
    $btn4.ForeColor = [System.Drawing.Color]::White; $btn4.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn4)
    $y += $bH + 6

    $sub4 = New-Object System.Windows.Forms.Label
    $sub4.Text      = 'Review per-user migration results and export status reports'
    $sub4.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sub4.ForeColor = $clrMuted
    $sub4.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $sub4.AutoSize  = $true
    $MenuForm.Controls.Add($sub4)
    $y += 26

    # ── 5. Monitor Projects ───────────────────────────────────────────────────
    $btn5 = New-Object System.Windows.Forms.Button
    $btn5.Text      = "5. Monitor Projects"
    $btn5.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $btn5.Location  = [System.Drawing.Point]::new($bX, $y)
    $btn5.Size      = [System.Drawing.Size]::new($bW, $bH)
    $btn5.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn5.FlatAppearance.BorderSize = 0; $btn5.BackColor = $clrAccent
    $btn5.ForeColor = [System.Drawing.Color]::White; $btn5.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn5)
    $y += $bH + 6

    $sub5 = New-Object System.Windows.Forms.Label
    $sub5.Text      = 'Live project monitoring and migration progress tracking'
    $sub5.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sub5.ForeColor = $clrMuted
    $sub5.Location  = [System.Drawing.Point]::new($bX + 4, $y)
    $sub5.AutoSize  = $true
    $MenuForm.Controls.Add($sub5)

    $MenuForm.ClientSize = [System.Drawing.Size]::new(480, ($y + 56))

    $footer = New-Object System.Windows.Forms.Panel
    $footer.Height = 46; $footer.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footer.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 38)
    $MenuForm.Controls.Add($footer)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Close'; $btnClose.Size = [System.Drawing.Size]::new(90, 30)
    $btnClose.Location = [System.Drawing.Point]::new(374, 8)
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(200, 55, 55)
    $btnClose.ForeColor = [System.Drawing.Color]::White; $btnClose.Font = $FontBold
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $footer.Controls.Add($btnClose)
    $footer.Add_SizeChanged({ $btnClose.Left = $footer.Width - 100 }.GetNewClosure())

    $btn1.Add_Click({ Show-AppRegistrationForm })
    $btn2.Add_Click({ Show-AosSetupForm })
    $btn3.Add_Click({ Show-MigrationRunnerForm })
    $btn4.Add_Click({ Show-ReportingForm })
    $btn5.Add_Click({
        if ($script:MonitorFormInstance -and
            -not $script:MonitorFormInstance.IsDisposed -and
            $script:MonitorFormInstance.Visible) {
            $script:MonitorFormInstance.BringToFront()
            $script:MonitorFormInstance.Focus()
        } else {
            Show-ProjectMonitorForm
        }
    })
    $btnClose.Add_Click({ $MenuForm.Close() }.GetNewClosure())

    [System.Windows.Forms.Application]::Run($MenuForm)
}

# ═════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═════════════════════════════════════════════════════════════════════════════
Show-MainMenu
