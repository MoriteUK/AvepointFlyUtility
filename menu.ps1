#Requires -Version 7.0
# AvePoint Fly Migration Toolkit - Entry Point

. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\settings.ps1"
. "$PSScriptRoot\appregistration.ps1"
. "$PSScriptRoot\aossetup.ps1"
. "$PSScriptRoot\runner.ps1"
. "$PSScriptRoot\monitor.ps1"
. "$PSScriptRoot\reports.ps1"

function Show-MainMenu {
    $MenuForm = New-Object System.Windows.Forms.Form
    $MenuForm.Text            = "AvePoint Fly"
    $MenuForm.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $MenuForm.ClientSize      = [System.Drawing.Size]::new(800, 750)
    $MenuForm.BackColor       = $clrBg
    $MenuForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $MenuForm.MaximizeBox     = $false
    $MenuForm.Font            = $FontBody
    $_ico = Join-Path $PSScriptRoot 'FlyMigration.ico'; if (Test-Path $_ico) { $MenuForm.Icon = [System.Drawing.Icon]::new($_ico) }

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(800, 72); $hdr.Dock = [System.Windows.Forms.DockStyle]::Top; $hdr.BackColor = $clrAccent
    $MenuForm.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 44
    $hdrTitle = New-Object System.Windows.Forms.Label
    $hdrTitle.Text      = "  🚀 AvePoint Fly"
    $hdrTitle.Font      = New-Object System.Drawing.Font('Segoe UI Semibold', 16)
    $hdrTitle.ForeColor = [System.Drawing.Color]::White
    $hdrTitle.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrTitle.Size      = [System.Drawing.Size]::new(680, 72)
    $hdrTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdr.Controls.Add($hdrTitle)

    $btnGear = New-Object System.Windows.Forms.Button
    $btnGear.BackColor = $clrAccent
    $btnGear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnGear.FlatAppearance.BorderSize = 0
    $btnGear.FlatAppearance.MouseOverBackColor = $clrAccentHover
    $btnGear.Size     = [System.Drawing.Size]::new(42, 42)
    $btnGear.Location = [System.Drawing.Point]::new(748, 15)
    $btnGear.Cursor   = [System.Windows.Forms.Cursors]::Hand
    $btnGear.Add_Click({ Show-SettingsDialog })
    if ($script:GearBitmap) {
        $btnGear.Image = $script:GearBitmap; $btnGear.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    } else {
        $btnGear.Text = [char]0x2699; $btnGear.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 20)
        $btnGear.ForeColor = [System.Drawing.Color]::White
    }
    $hdr.Controls.Add($btnGear)

    # Card helper function with rounded corners and blue top edge
    function MkCard { param([int]$X,[int]$Y,[int]$W,[int]$H,[string]$Title,[string]$Subtitle)
        $card = New-Object System.Windows.Forms.Panel
        $card.Location = [System.Drawing.Point]::new($X,$Y)
        $card.Size = [System.Drawing.Size]::new($W,$H)
        $card.BackColor = [System.Drawing.Color]::White
        $card.BorderStyle = [System.Windows.Forms.BorderStyle]::None
        $card.Cursor = [System.Windows.Forms.Cursors]::Hand

        # Add rounded corners with blue top edge
        $card.Add_Paint({
            param($sender, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

            # Create rounded rectangle path
            $radius = 12
            $rect = [System.Drawing.Rectangle]::new(0, 0, $sender.Width - 1, $sender.Height - 1)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath

            $path.AddArc($rect.X, $rect.Y, $radius * 2, $radius * 2, 180, 90)
            $path.AddArc($rect.Right - $radius * 2, $rect.Y, $radius * 2, $radius * 2, 270, 90)
            $path.AddArc($rect.Right - $radius * 2, $rect.Bottom - $radius * 2, $radius * 2, $radius * 2, 0, 90)
            $path.AddArc($rect.X, $rect.Bottom - $radius * 2, $radius * 2, $radius * 2, 90, 90)
            $path.CloseFigure()

            # Fill background
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $g.FillPath($brush, $path)

            # Draw border
            $pen = New-Object System.Drawing.Pen($clrBorder, 1)
            $g.DrawPath($pen, $path)

            # Draw blue top edge (gradient bar)
            $topPath = New-Object System.Drawing.Drawing2D.GraphicsPath
            $topPath.AddArc($rect.X, $rect.Y, $radius * 2, $radius * 2, 180, 90)
            $topPath.AddLine($rect.X + $radius, $rect.Y, $rect.Right - $radius, $rect.Y)
            $topPath.AddArc($rect.Right - $radius * 2, $rect.Y, $radius * 2, $radius * 2, 270, 90)
            $topPath.AddLine($rect.Right, $rect.Y + $radius, $rect.Right, $rect.Y + 4)
            $topPath.AddLine($rect.Right, $rect.Y + 4, $rect.X, $rect.Y + 4)
            $topPath.CloseFigure()

            $gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                [System.Drawing.Point]::new(0, 0),
                [System.Drawing.Point]::new($sender.Width, 0),
                $clrAccent,
                [System.Drawing.Color]::FromArgb(0, 82, 163)
            )
            $g.FillPath($gradientBrush, $topPath)

            $brush.Dispose()
            $pen.Dispose()
            $path.Dispose()
            $topPath.Dispose()
            $gradientBrush.Dispose()
        }.GetNewClosure())

        # Title label
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = $Title
        $lblTitle.Location = [System.Drawing.Point]::new(16, 20)
        $lblTitle.AutoSize = $true
        $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
        $lblTitle.ForeColor = $clrText
        $card.Controls.Add($lblTitle)

        # Subtitle label
        $lblSub = New-Object System.Windows.Forms.Label
        $lblSub.Text = $Subtitle
        $lblSub.Location = [System.Drawing.Point]::new(16, 46)
        $lblSub.Size = [System.Drawing.Size]::new($W - 32, 50)
        $lblSub.Font = $FontSub
        $lblSub.ForeColor = $clrMuted
        $card.Controls.Add($lblSub)

        $MenuForm.Controls.Add($card)
        return $card
    }

    # 3 cards wide layout
    $cardW = 240; $cardH = 120; $startX = 40; $gap = 20
    $y = 112

    # Row 1 (3 cards)
    $card1 = MkCard $startX $y $cardW $cardH '🔐 App Registration' 'Register the Entra ID app and grant API permissions'
    $card2 = MkCard ($startX + $cardW + $gap) $y $cardW $cardH '⚙️ AOS Setup' 'Configure AvePoint Online Services tenant'
    $card3 = MkCard ($startX + ($cardW + $gap) * 2) $y $cardW $cardH '🔗 Connections' 'Manage connections and mappings'
    $y += $cardH + $gap

    # Row 2 (2 cards)
    $card4 = MkCard $startX $y $cardW $cardH '📊 Reports' 'View migration results and status'
    $card5 = MkCard ($startX + $cardW + $gap) $y $cardW $cardH '📈 Monitor' 'Live project monitoring'

    $footer = New-Object System.Windows.Forms.Panel
    $footer.Height = 64; $footer.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footer.BackColor = $clrFooter
    $MenuForm.Controls.Add($footer)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Close'; $btnClose.Size = [System.Drawing.Size]::new(100, 36)
    $btnClose.Location = [System.Drawing.Point]::new(680, 14)
    $btnClose.BackColor = $clrCloseRed
    $btnClose.ForeColor = [System.Drawing.Color]::White; $btnClose.Font = $FontBold
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $footer.Controls.Add($btnClose)
    $footer.Add_SizeChanged({ $btnClose.Left = $footer.Width - 106 }.GetNewClosure())

    $card1.Add_Click({ Show-AppRegistrationForm })
    $card2.Add_Click({ Show-AosSetupForm })
    $card3.Add_Click({ Show-MigrationRunnerForm })
    $card4.Add_Click({ Show-ReportingForm })
    $card5.Add_Click({
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
