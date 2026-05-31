#Requires -Version 5.1
# AvePoint Fly - Merged entry point

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
[System.Windows.Forms.Application]::EnableVisualStyles()

# Minimize the console window so the GUI stands alone on screen
Add-Type -Namespace FlyConsole -Name NativeMethods -MemberDefinition '
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
' -ErrorAction SilentlyContinue
$_consoleHwnd = [FlyConsole.NativeMethods]::GetConsoleWindow()
if ($_consoleHwnd -ne [IntPtr]::Zero) {
    [FlyConsole.NativeMethods]::ShowWindow($_consoleHwnd, 6) | Out-Null  # SW_MINIMIZE
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
        $icon = [System.Drawing.Icon]::new($icoPath, $LogoH, $LogoH)
        $img  = $icon.ToBitmap()
        $icon.Dispose()
    } elseif (Test-Path $pngPath) {
        $img = [System.Drawing.Image]::FromFile($pngPath)
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
    if ($script:LogFile) { "$ts [$Level] $Msg" | Add-Content -Path $script:LogFile -Encoding UTF8 }
    [System.Windows.Forms.Application]::DoEvents()
}

# ═════════════════════════════════════════════════════════════════════════════
# APP REGISTRATION
# ═════════════════════════════════════════════════════════════════════════════
function Show-AppRegistrationForm {

    function New-Card {
        param($Parent, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Title = "")
        $outer = New-Object System.Windows.Forms.Panel
        $outer.Location  = [System.Drawing.Point]::new($X, $Y)
        $outer.Size      = [System.Drawing.Size]::new($W, $H)
        $outer.BackColor = $clrBorder
        $Parent.Controls.Add($outer)
        $inner = New-Object System.Windows.Forms.Panel
        $inner.Location  = [System.Drawing.Point]::new(1, 1)
        $inner.Size      = [System.Drawing.Size]::new($W - 2, $H - 2)
        $inner.BackColor = $clrPanel
        $outer.Controls.Add($inner)
        $bar = New-Object System.Windows.Forms.Panel
        $bar.Location  = [System.Drawing.Point]::new(0, 0)
        $bar.Size      = [System.Drawing.Size]::new(4, $H - 2)
        $bar.BackColor = $clrAccent
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
        $l.AutoSize = $true
        $l.Font = if ($Bold) { $FontBold } else { $FontBody }
        $l.ForeColor = $clrText
        $Parent.Controls.Add($l)
        return $l
    }

    function New-TB {
        param($Parent, [int]$X, [int]$Y, [int]$W,
              [bool]$Password = $false, [string]$Default = "")
        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Location    = [System.Drawing.Point]::new($X, $Y)
        $tb.Size        = [System.Drawing.Size]::new($W, 24)
        $tb.Font        = $FontBody
        $tb.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $tb.Text        = $Default
        if ($Password) { $tb.UseSystemPasswordChar = $true }
        $Parent.Controls.Add($tb)
        return $tb
    }

    function New-Btn {
        param($Parent, [string]$Text, [int]$X, [int]$Y,
              [int]$W = 140, [int]$H = 30, [bool]$Primary = $true)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $Text; $b.Location = [System.Drawing.Point]::new($X, $Y)
        $b.Size = [System.Drawing.Size]::new($W, $H); $b.Font = $FontBold
        $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $b.FlatAppearance.BorderSize = 0
        $b.BackColor = if ($Primary) { $clrAccent } else { [System.Drawing.Color]::FromArgb(225, 228, 238) }
        $b.ForeColor = if ($Primary) { [System.Drawing.Color]::White } else { $clrText }
        $b.Cursor = [System.Windows.Forms.Cursors]::Hand
        $Parent.Controls.Add($b)
        return $b
    }

    function New-Dot {
        param($Parent, [int]$X, [int]$Y)
        $d = New-Object System.Windows.Forms.Label
        $d.Text = [char]0x25CF; $d.Font = New-Object System.Drawing.Font("Segoe UI", 13)
        $d.ForeColor = $clrGrey; $d.Location = [System.Drawing.Point]::new($X, $Y); $d.AutoSize = $true
        $Parent.Controls.Add($d)
        return $d
    }

    function Write-Log {
        param([string]$Msg, [string]$Level = "INFO")
        $ts = Get-Date -Format "HH:mm:ss"
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

    function Invoke-GraphApi {
        param([string]$Method = "GET", [string]$Endpoint, $Body = $null)
        $p = @{
            Method      = $Method
            Uri         = "https://graph.microsoft.com/v1.0$Endpoint"
            Headers     = @{ Authorization = "Bearer $($script:GraphToken)"; "Content-Type" = "application/json" }
            ErrorAction = "Stop"
        }
        if ($Body) { $p.Body = ($Body | ConvertTo-Json -Depth 10) }
        return Invoke-RestMethod @p
    }

    $Form = New-Object System.Windows.Forms.Form
    $Form.Text            = "AvePoint Fly - Target Tenant App Registration"
    $Form.ClientSize      = [System.Drawing.Size]::new(780, 680)
    $Form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $Form.BackColor       = $clrBg
    $Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $Form.MaximizeBox     = $false
    $Form.Font            = $FontBody

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(780, 54); $hdr.BackColor = $clrAccent
    $Form.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 34
    $hdrTitle = New-Object System.Windows.Forms.Label
    $hdrTitle.Text      = "  Target Tenant App Registration"
    $hdrTitle.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
    $hdrTitle.ForeColor = [System.Drawing.Color]::White
    $hdrTitle.Location  = [System.Drawing.Point]::new($_hdrX, 15); $hdrTitle.AutoSize = $true
    $hdr.Controls.Add($hdrTitle)

    $s1 = New-Card -Parent $Form -X 14 -Y 64 -W 752 -H 100 -Title "STEP 1  -  TARGET TENANT"
    New-Lbl $s1 "App Name"      16  33 | Out-Null
    New-Lbl $s1 "Tenant Domain" 310 33 | Out-Null
    $tbAppName = New-TB $s1 16  51 278 -Default "AvePoint Fly Migration"
    $tbTenant  = New-TB $s1 310 51 260 -Default "contoso.onmicrosoft.com"

    $rdoNew = New-Object System.Windows.Forms.RadioButton
    $rdoNew.Text = "Register new app"; $rdoNew.Font = $FontBody
    $rdoNew.Location = [System.Drawing.Point]::new(590, 48); $rdoNew.AutoSize = $true; $rdoNew.Checked = $true
    $s1.Controls.Add($rdoNew)

    $rdoExist = New-Object System.Windows.Forms.RadioButton
    $rdoExist.Text = "Use existing app"; $rdoExist.Font = $FontBody
    $rdoExist.Location = [System.Drawing.Point]::new(590, 70); $rdoExist.AutoSize = $true
    $s1.Controls.Add($rdoExist)

    $s2 = New-Card -Parent $Form -X 14 -Y 174 -W 752 -H 80 -Title "STEP 2  -  EXISTING APP CREDENTIALS (if using existing)"
    New-Lbl $s2 "Client ID"     16 33 | Out-Null
    New-Lbl $s2 "Client Secret" 370 33 | Out-Null
    $tbClientId     = New-TB $s2 16  51 340
    $tbClientSecret = New-TB $s2 370 51 270 -Password $true
    $tbClientId.Enabled = $false; $tbClientSecret.Enabled = $false

    $rdoExist.Add_CheckedChanged({
        $tbClientId.Enabled     = $rdoExist.Checked
        $tbClientSecret.Enabled = $rdoExist.Checked
    })

    $s3 = New-Card -Parent $Form -X 14 -Y 264 -W 752 -H 68 -Title ""
    $btnReg = New-Btn $s3 "Authenticate and Register" 16 18 210 34
    $dotReg = New-Dot $s3 238 20

    $lblResult = New-Object System.Windows.Forms.Label
    $lblResult.Location  = [System.Drawing.Point]::new(258, 26)
    $lblResult.Size      = [System.Drawing.Size]::new(330, 20)
    $lblResult.Font      = $FontBody; $lblResult.ForeColor = $clrMuted; $lblResult.Text = "Waiting..."
    $s3.Controls.Add($lblResult)

    $btnCloseForm = New-Btn $s3 "Close" 600 18 130 34 $false
    $btnCloseForm.Add_Click({ $Form.Close() })

    $s4 = New-Card -Parent $Form -X 14 -Y 342 -W 752 -H 100 -Title "OUTPUT  -  Copy these values into Fly connections"
    New-Lbl $s4 "Tenant ID"       16 33 | Out-Null
    New-Lbl $s4 "App (Client) ID" 16 58 | Out-Null
    $tbOutTenantId = New-TB $s4 130 30 478 -Default ""
    $tbOutAppId    = New-TB $s4 130 55 330 -Default ""
    $tbOutTenantId.ReadOnly = $true; $tbOutTenantId.BackColor = [System.Drawing.Color]::FromArgb(245,247,252)
    $tbOutAppId.ReadOnly    = $true; $tbOutAppId.BackColor    = [System.Drawing.Color]::FromArgb(245,247,252)
    $btnCopyTenantId = New-Btn $s4 "Copy"        618  26  96 28 $false
    $btnCopyAppId    = New-Btn $s4 "Copy"        468  52  96 28 $false
    $btnCopySecret   = New-Btn $s4 "Copy Secret" 572  52 112 28 $false
    $btnCopyTenantId.Enabled = $false
    $btnCopyAppId.Enabled    = $false
    $btnCopySecret.Enabled   = $false

    $s5 = New-Card -Parent $Form -X 14 -Y 452 -W 752 -H 214 -Title "LOG"
    $script:rtbLog = New-Object System.Windows.Forms.RichTextBox
    $script:rtbLog.Location    = [System.Drawing.Point]::new(16, 26)
    $script:rtbLog.Size        = [System.Drawing.Size]::new(716, 178)
    $script:rtbLog.Font        = $FontMono; $script:rtbLog.BackColor = $clrLogBg
    $script:rtbLog.ForeColor   = [System.Drawing.Color]::FromArgb(190, 210, 255)
    $script:rtbLog.ReadOnly    = $true; $script:rtbLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $script:rtbLog.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $s5.Controls.Add($script:rtbLog)

    $script:PlainSecret = $null
    $btnCopySecret.Add_Click({
        if ($script:PlainSecret) {
            [System.Windows.Forms.Clipboard]::SetText($script:PlainSecret)
            Write-Log "Client secret copied to clipboard." "OK"
        }
    })
    $btnCopyTenantId.Add_Click({
        if ($tbOutTenantId.Text) {
            [System.Windows.Forms.Clipboard]::SetText($tbOutTenantId.Text)
            Write-Log "Tenant ID copied to clipboard." "OK"
        }
    })
    $btnCopyAppId.Add_Click({
        if ($tbOutAppId.Text) {
            [System.Windows.Forms.Clipboard]::SetText($tbOutAppId.Text)
            Write-Log "App (Client) ID copied to clipboard." "OK"
        }
    })

    $btnReg.Add_Click({
        $btnReg.Enabled        = $false
        $dotReg.ForeColor      = $clrGrey
        $lblResult.Text        = "Working..."
        $lblResult.ForeColor   = $clrMuted
        $btnCopySecret.Enabled = $false

        try {
            $tenantDomain = $tbTenant.Text.Trim()
            $appName      = $tbAppName.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($tenantDomain)) { throw "Tenant domain is required." }
            if ([string]::IsNullOrWhiteSpace($appName))      { throw "App name is required." }

            Write-Log "Resolving tenant ID for $tenantDomain..."
            $oidc = Invoke-RestMethod `
                -Uri "https://login.microsoftonline.com/$tenantDomain/.well-known/openid-configuration" `
                -ErrorAction Stop
            $tenantId = ($oidc.issuer -split "/")[3]
            Write-Log "Tenant ID: $tenantId"

            if ($rdoExist.Checked) {
                $appId     = $tbClientId.Text.Trim()
                $appSecret = $tbClientSecret.Text.Trim()
                if ([string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($appSecret)) {
                    throw "Client ID and Secret are required for existing app."
                }
                Write-Log "Using existing app: $appId" "OK"
                $script:PlainSecret = $appSecret
                Write-Log "Existing app - verify API permissions and Exchange Administrator role are configured in Entra ID." "WARN"
            }
            else {
                $publicClientId = "1950a258-227b-4e31-a9cf-717495945fc2"
                $escapedScope   = [Uri]::EscapeDataString("https://graph.microsoft.com/.default")

                Write-Log "Starting device code flow..."
                $dcBody = "client_id=$publicClientId" + "&scope=$escapedScope"
                $dcResp = Invoke-RestMethod -Method POST `
                    -Uri "https://login.microsoftonline.com/$tenantDomain/oauth2/v2.0/devicecode" `
                    -Body $dcBody -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop

                Write-Log "URL:  $($dcResp.verification_uri)" "WARN"
                Write-Log "Code: $($dcResp.user_code)" "WARN"

                [System.Windows.Forms.MessageBox]::Show(
                    "Sign in as Global Admin in the TARGET tenant:`n`n" +
                    "URL:   $($dcResp.verification_uri)`n" +
                    "Code:  $($dcResp.user_code)`n`n" +
                    "Click OK after completing sign-in.",
                    "Target Tenant Authentication",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null

                Write-Log "Polling for token..."
                $tokenUrl  = "https://login.microsoftonline.com/$tenantDomain/oauth2/v2.0/token"
                $grantType = [Uri]::EscapeDataString("urn:ietf:params:oauth:grant-type:device_code")
                $script:GraphToken = $null
                $attempts = 0
                while ((-not $script:GraphToken) -and $attempts -lt 40) {
                    Start-Sleep -Seconds 3; $attempts++
                    try {
                        $tokenBody = "client_id=$publicClientId" + "&grant_type=$grantType" + "&device_code=$($dcResp.device_code)"
                        $tr = Invoke-RestMethod -Method POST -Uri $tokenUrl `
                            -Body $tokenBody -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
                        $script:GraphToken = $tr.access_token
                    } catch { }
                }
                if (-not $script:GraphToken) { throw "Authentication timed out." }
                Write-Log "Authenticated OK" "OK"

                Write-Log "Registering app: $appName..."
                $newApp = Invoke-GraphApi -Method POST -Endpoint "/applications" -Body @{
                    displayName    = $appName
                    signInAudience = "AzureADMyOrg"
                }
                $appId = $newApp.appId

                Write-Log "Creating service principal..."
                $newSP = Invoke-GraphApi -Method POST -Endpoint "/servicePrincipals" -Body @{ appId = $appId }

                Write-Log "Creating client secret (1 year)..."
                $secretResp = Invoke-GraphApi -Method POST `
                    -Endpoint "/applications/$($newApp.id)/addPassword" -Body @{
                        passwordCredential = @{
                            displayName = "FlyMigration"
                            endDateTime = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
                        }
                    }
                $script:PlainSecret = $secretResp.secretText
                Write-Log "Secret expires: $($secretResp.endDateTime)" "OK"
                Update-SharedConfig @{ SecretExpiry = $secretResp.endDateTime }

                Write-Log "Resolving resource service principals..."
                $graphResSP = $null
                $exoResSP   = $null

                Write-Log "Looking up Microsoft Graph service principal..." "INFO"
                try {
                    $gResult = Invoke-GraphApi -Endpoint "/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=id,appRoles"
                    $graphResSP = $gResult.value | Select-Object -First 1
                    if ($graphResSP) {
                        Write-Log "Microsoft Graph SP found (id: $($graphResSP.id))" "INFO"
                    } else {
                        Write-Log "Microsoft Graph SP not in results — activating..." "INFO"
                        Invoke-GraphApi -Method POST -Endpoint "/servicePrincipals" -Body @{ appId = '00000003-0000-0000-c000-000000000000' } | Out-Null
                        Start-Sleep -Seconds 3
                        $gResult2 = Invoke-GraphApi -Endpoint "/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=id,appRoles"
                        $graphResSP = $gResult2.value | Select-Object -First 1
                        if ($graphResSP) { Write-Log "Microsoft Graph SP activated OK" "INFO" }
                        else { Write-Log "Microsoft Graph SP still not found after activation" "WARN" }
                    }
                } catch {
                    Write-Log "Microsoft Graph SP error: $($_.Exception.Message)" "WARN"
                }

                Write-Log "Looking up Exchange Online service principal..." "INFO"
                try {
                    $eResult = Invoke-GraphApi -Endpoint "/servicePrincipals?`$filter=appId eq '00000002-0000-0ff1-ce00-000000000000'&`$select=id,appRoles"
                    $exoResSP = $eResult.value | Select-Object -First 1
                    if ($exoResSP) {
                        Write-Log "Exchange Online SP found (id: $($exoResSP.id))" "INFO"
                    } else {
                        Write-Log "Exchange Online SP not in results — activating..." "INFO"
                        Invoke-GraphApi -Method POST -Endpoint "/servicePrincipals" -Body @{ appId = '00000002-0000-0ff1-ce00-000000000000' } | Out-Null
                        Start-Sleep -Seconds 3
                        $eResult2 = Invoke-GraphApi -Endpoint "/servicePrincipals?`$filter=appId eq '00000002-0000-0ff1-ce00-000000000000'&`$select=id,appRoles"
                        $exoResSP = $eResult2.value | Select-Object -First 1
                        if ($exoResSP) { Write-Log "Exchange Online SP activated OK" "INFO" }
                        else { Write-Log "Exchange Online SP still not found after activation" "WARN" }
                    }
                } catch {
                    Write-Log "Exchange Online SP error: $($_.Exception.Message)" "WARN"
                }

                if ($graphResSP -and $exoResSP) {
                    $graphPermNames = @(
                        'Directory.ReadWrite.All', 'User.ReadWrite.All',
                        'Group.ReadWrite.All', 'GroupMember.ReadWrite.All',
                        'Sites.FullControl.All', 'Files.ReadWrite.All',
                        'Mail.ReadWrite', 'MailboxSettings.ReadWrite',
                        'Calendars.ReadWrite', 'Contacts.ReadWrite', 'Notes.ReadWrite.All',
                        'TeamSettings.ReadWrite.All', 'Channel.ReadWrite.All',
                        'ChannelMember.ReadWrite.All', 'Chat.ReadWrite.All'
                    )
                    $exoPermNames = @('Exchange.ManageAsApp')

                    $graphRoles = $graphPermNames | ForEach-Object {
                        $n = $_
                        $r = $graphResSP.appRoles | Where-Object value -eq $n | Select-Object -First 1
                        if (-not $r) { Write-Log "Graph permission '$n' not found - skipping" "WARN" }
                        $r
                    } | Where-Object { $_ }

                    $exoRoles = $exoPermNames | ForEach-Object {
                        $n = $_
                        $r = $exoResSP.appRoles | Where-Object value -eq $n | Select-Object -First 1
                        if (-not $r) { Write-Log "EXO permission '$n' not found - skipping" "WARN" }
                        $r
                    } | Where-Object { $_ }

                    Write-Log "Adding $($graphRoles.Count + $exoRoles.Count) API permissions to app registration..."
                    Invoke-GraphApi -Method PATCH -Endpoint "/applications/$($newApp.id)" -Body @{
                        requiredResourceAccess = @(
                            @{
                                resourceAppId  = '00000003-0000-0000-c000-000000000000'
                                resourceAccess = @($graphRoles | ForEach-Object { @{ id = $_.id; type = 'Role' } })
                            }
                            @{
                                resourceAppId  = '00000002-0000-0ff1-ce00-000000000000'
                                resourceAccess = @($exoRoles | ForEach-Object { @{ id = $_.id; type = 'Role' } })
                            }
                        )
                    } | Out-Null
                    Write-Log "Permissions added to app registration." "OK"

                    Write-Log "Granting admin consent..."
                    $granted = 0; $skipped = 0
                    foreach ($role in $graphRoles) {
                        try {
                            Invoke-GraphApi -Method POST -Endpoint "/servicePrincipals/$($newSP.id)/appRoleAssignments" -Body @{
                                principalId = $newSP.id; resourceId = $graphResSP.id; appRoleId = $role.id
                            } | Out-Null
                            $granted++
                        } catch {
                            if ($_.Exception.Message -like "*already exists*") { $skipped++ }
                            else { Write-Log "Consent warning '$($role.value)': $($_.Exception.Message)" "WARN" }
                        }
                    }
                    foreach ($role in $exoRoles) {
                        try {
                            Invoke-GraphApi -Method POST -Endpoint "/servicePrincipals/$($newSP.id)/appRoleAssignments" -Body @{
                                principalId = $newSP.id; resourceId = $exoResSP.id; appRoleId = $role.id
                            } | Out-Null
                            $granted++
                        } catch {
                            if ($_.Exception.Message -like "*already exists*") { $skipped++ }
                            else { Write-Log "Consent warning '$($role.value)': $($_.Exception.Message)" "WARN" }
                        }
                    }
                    Write-Log "Admin consent: $granted granted, $skipped already existed." "OK"
                } else {
                    Write-Log "Could not resolve Graph/EXO service principals - skipping consent grant." "WARN"
                    Write-Log "Grant admin consent manually in Entra ID > App registrations > API permissions." "WARN"
                }

                Write-Log "Assigning Exchange Administrator role to service principal..."
                $exAdminRole = $null
                try {
                    $exAdminRole = (Invoke-GraphApi -Endpoint "/directoryRoles?`$filter=displayName eq 'Exchange Administrator'").value | Select-Object -First 1
                } catch { }
                if (-not $exAdminRole) {
                    $tmpl = (Invoke-GraphApi -Endpoint "/directoryRoleTemplates?`$filter=displayName eq 'Exchange Administrator'").value | Select-Object -First 1
                    if ($tmpl) { $exAdminRole = Invoke-GraphApi -Method POST -Endpoint "/directoryRoles" -Body @{ roleTemplateId = $tmpl.id } }
                }
                if ($exAdminRole) {
                    try {
                        Invoke-GraphApi -Method POST -Endpoint "/directoryRoles/$($exAdminRole.id)/members/`$ref" -Body @{
                            '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($newSP.id)"
                        } | Out-Null
                        Write-Log "Exchange Administrator role assigned." "OK"
                    } catch {
                        if ($_.Exception.Message -like "*already exists*" -or
                            $_.Exception.Message -like "*One or more added object references already exist*") {
                            Write-Log "Exchange Administrator role already assigned." "OK"
                        } else {
                            Write-Log "Exchange Administrator role assignment: $($_.Exception.Message)" "WARN"
                        }
                    }
                } else {
                    Write-Log "Exchange Administrator role not found in directory." "WARN"
                }
            }

            $tbOutTenantId.Text    = $tenantId
            $tbOutAppId.Text       = $appId
            Update-SharedConfig @{ AppName = $appName; TenantDomain = $tenantDomain; TenantId = $tenantId; AppId = $appId }
            $btnCopyTenantId.Enabled = $true
            $btnCopyAppId.Enabled    = $true
            $btnCopySecret.Enabled   = $true
            $dotReg.ForeColor        = $clrGreen
            $lblResult.Text        = "App ID: $appId"
            $lblResult.ForeColor   = $clrGreen
            Write-Log "Complete" "OK"
        }
        catch {
            $dotReg.ForeColor    = $clrRed
            $lblResult.Text      = "Failed - see log"
            $lblResult.ForeColor = $clrRed
            $btnReg.Enabled      = $true
            Write-Log "Failed: $($_.Exception.Message)" "ERROR"
        }
    })

    $_sc = Read-SharedConfig
    if ($_sc.TenantDomain -and $tbTenant.Text -eq "contoso.onmicrosoft.com") { $tbTenant.Text  = $_sc.TenantDomain }
    if ($_sc.AppName      -and $tbAppName.Text -eq "AvePoint Fly Migration")  { $tbAppName.Text = $_sc.AppName }
    Write-Log "Enter target tenant details and click Authenticate and Register."
    [System.Windows.Forms.Application]::Run($Form)
}

# ═════════════════════════════════════════════════════════════════════════════
# CONNECTION CREATOR (WPF)
# $script:ctrl / $script:wpfResults / $script:wpfWindow are $script:-scoped so
# nested helper functions can reach them without closure capture.
# ═════════════════════════════════════════════════════════════════════════════
function Show-ConnectionsForm {

    $script:connSvcDef = @(
        [pscustomobject]@{ Label='Exchange Online';      CheckboxName='ChkExo'    }
        [pscustomobject]@{ Label='SharePoint Online';    CheckboxName='ChkSpo'    }
        [pscustomobject]@{ Label='OneDrive';             CheckboxName='ChkOd4b'   }
        [pscustomobject]@{ Label='Microsoft Teams';      CheckboxName='ChkTeams'  }
        [pscustomobject]@{ Label='Microsoft Teams Chat'; CheckboxName='ChkChat'   }
        [pscustomobject]@{ Label='Microsoft 365 Groups'; CheckboxName='ChkGroups' }
    )

    $script:connectorJs  = Join-Path $PSScriptRoot 'fly-connector.js'
    $script:connSettings = Join-Path $env:LOCALAPPDATA 'FlyConnectionCreator\settings.json'

    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AvePoint Fly - Connection Creator"
        Height="780" Width="980"
        WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" FontSize="13"
        Background="#F0F2F7">
    <Window.Resources>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="Margin" Value="0,2,0,8"/>
            <Setter Property="BorderBrush" Value="#D2D7E4"/>
            <Setter Property="Background" Value="White"/>
        </Style>
        <Style TargetType="Label">
            <Setter Property="Padding" Value="0,4,8,0"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="#1C1C20"/>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Margin" Value="0,0,0,10"/>
            <Setter Property="Padding" Value="12,8,12,8"/>
            <Setter Property="BorderBrush" Value="#D2D7E4"/>
            <Setter Property="Background" Value="White"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="14,6"/>
            <Setter Property="Margin" Value="0,0,8,0"/>
            <Setter Property="MinWidth" Value="140"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#F0F2F7"/>
            <Setter Property="Foreground" Value="#1C1C20"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="BorderBrush" Value="#D2D7E4"/>
            <Setter Property="BorderThickness" Value="0,0,0,1"/>
        </Style>
    </Window.Resources>

    <DockPanel>
        <Border DockPanel.Dock="Top" Background="#0064B4" Padding="16,8">
            <DockPanel LastChildFill="True">
                <Image Name="ImgLogo" DockPanel.Dock="Left" Height="34" Margin="0,0,12,0"
                       VerticalAlignment="Center" Stretch="Uniform"
                       RenderOptions.BitmapScalingMode="HighQuality"/>
                <TextBlock FontFamily="Segoe UI Semibold" FontSize="15" Foreground="White" VerticalAlignment="Center">
                    <Run Text="Connection Creator" FontWeight="Light"/>
                </TextBlock>
            </DockPanel>
        </Border>

        <Grid Margin="16,12,16,16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <GroupBox Grid.Row="0" Header="AOS Sign-in (one-time, session persisted)">
            <StackPanel Orientation="Horizontal">
                <Button Name="BtnSignIn" Content="Sign in to AOS..." Background="#0064B4" Foreground="White" FontWeight="SemiBold"/>
                <TextBlock Name="TxtAuthStatus" VerticalAlignment="Center" Margin="8,0,0,0" Foreground="#666"
                           Text="Click to sign in - opens Chrome, complete Microsoft SSO, then close it."/>
            </StackPanel>
        </GroupBox>

        <GroupBox Grid.Row="1" Header="Tenant">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="160"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="20"/>
                    <ColumnDefinition Width="160"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition/>
                    <RowDefinition/>
                </Grid.RowDefinitions>
                <Label   Grid.Row="0" Grid.Column="0" Content="Display Name:"/>
                <TextBox Grid.Row="0" Grid.Column="1" Name="TxtTenantName" ToolTip="Used in the Connection name, e.g. OurVolaris"/>
                <Label   Grid.Row="0" Grid.Column="3" Content="Search Code:"/>
                <TextBox Grid.Row="0" Grid.Column="4" Name="TxtTenantSearch" ToolTip="Short code shown in AOS Tenant dropdown, e.g. ourvolaris"/>
                <Label   Grid.Row="1" Grid.Column="0" Content="Credentials Name:"/>
                <TextBox Grid.Row="1" Grid.Column="1" Name="TxtCredentialsName" ToolTip="Substring matched against App profile and Service account dropdowns, e.g. ITVolaris"/>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="2" Header="Workloads">
            <WrapPanel>
                <CheckBox Name="ChkExo"    Content="Exchange Online"       IsChecked="True" Margin="0,4,28,4"/>
                <CheckBox Name="ChkSpo"    Content="SharePoint Online"     IsChecked="True" Margin="0,4,28,4"/>
                <CheckBox Name="ChkOd4b"   Content="OneDrive"              IsChecked="True" Margin="0,4,28,4"/>
                <CheckBox Name="ChkTeams"  Content="Microsoft Teams"       IsChecked="True" Margin="0,4,28,4"/>
                <CheckBox Name="ChkChat"   Content="Microsoft Teams Chat"  IsChecked="True" Margin="0,4,28,4"/>
                <CheckBox Name="ChkGroups" Content="Microsoft 365 Groups"  IsChecked="True" Margin="0,4,28,4"/>
            </WrapPanel>
        </GroupBox>

        <Grid Grid.Row="3" Margin="0,4,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                <TextBlock Text="Connection type:" VerticalAlignment="Center" Margin="4,0,10,0"
                           FontWeight="SemiBold" Foreground="#1C1C20"/>
                <RadioButton Name="RdoDestination" Content="Destination tenant" IsChecked="True"
                             VerticalAlignment="Center" Margin="0,0,16,0"/>
                <RadioButton Name="RdoSource"      Content="Source tenant"
                             VerticalAlignment="Center"/>
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
                <Button Name="BtnOpenLogs" Content="Open Logs Folder"/>
                <Button Name="BtnClear"    Content="Clear Results"/>
                <Button Name="BtnSaveLog"  Content="Save Log..."/>
                <Button Name="BtnCancel"   Content="Stop"             IsEnabled="False"/>
                <Button Name="BtnCreate"   Content="Create Connections"
                        Background="#0064B4" Foreground="White" FontWeight="SemiBold"/>
                <Button Name="BtnClose"    Content="Close" Margin="16,0,0,0"
                        Background="#E1E4EE" Foreground="#1C1C20" BorderThickness="0"/>
            </StackPanel>
        </Grid>

        <DataGrid Grid.Row="4" Name="DgResults" AutoGenerateColumns="False"
                  IsReadOnly="True" HeadersVisibility="Column"
                  GridLinesVisibility="Horizontal"
                  AlternatingRowBackground="#F5F6FA"
                  Background="White" BorderBrush="#D2D7E4"
                  RowHeight="28" FontSize="12">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Time"             Binding="{Binding Timestamp}"      Width="80"/>
                <DataGridTextColumn Header="Workload"         Binding="{Binding Workload}"       Width="180"/>
                <DataGridTextColumn Header="Connection Name"  Binding="{Binding ConnectionName}" Width="260"/>
                <DataGridTextColumn Header="Status"           Binding="{Binding Status}"         Width="100">
                    <DataGridTextColumn.CellStyle>
                        <Style TargetType="DataGridCell">
                            <Setter Property="FontWeight" Value="SemiBold"/>
                            <Setter Property="Padding" Value="6,0"/>
                            <Style.Triggers>
                                <DataTrigger Binding="{Binding Status}" Value="CREATED"><Setter Property="Foreground" Value="#107C10"/></DataTrigger>
                                <DataTrigger Binding="{Binding Status}" Value="FAILED"> <Setter Property="Foreground" Value="#D13438"/></DataTrigger>
                                <DataTrigger Binding="{Binding Status}" Value="SKIPPED"><Setter Property="Foreground" Value="#808080"/></DataTrigger>
                                <DataTrigger Binding="{Binding Status}" Value="WORKING"><Setter Property="Foreground" Value="#0064B4"/></DataTrigger>
                            </Style.Triggers>
                        </Style>
                    </DataGridTextColumn.CellStyle>
                </DataGridTextColumn>
                <DataGridTextColumn Header="Message" Binding="{Binding Message}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>

        <Border Grid.Row="5" Background="#EEF0F5" Padding="10,6" Margin="0,8,0,0" BorderBrush="#D2D7E4" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Name="TxtStatus"  Text="Ready" Foreground="#646C78"/>
                <TextBlock Grid.Column="1" Name="TxtSummary" Text="" FontWeight="SemiBold" Foreground="#1C1C20"/>
            </Grid>
        </Border>
        </Grid>
    </DockPanel>
</Window>
'@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $script:wpfWindow = [Windows.Markup.XamlReader]::Load($reader)

    $script:ctrl = @{}
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object { $script:ctrl[$_.Name] = $script:wpfWindow.FindName($_.Name) }

    # Load icon (prefer FlyMigration.ico, fall back to ourvolaris.png)
    $_iconFile = Join-Path $PSScriptRoot "FlyMigration.ico"
    if (-not (Test-Path $_iconFile)) { $_iconFile = Join-Path $PSScriptRoot "ourvolaris.png" }
    if (Test-Path $_iconFile) {
        $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
            [System.Uri]::new($_iconFile),
            [System.Windows.Media.Imaging.BitmapCreateOptions]::None,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $script:ctrl['ImgLogo'].Source = ($dec.Frames | Sort-Object PixelWidth | Select-Object -Last 1)
    }

    $script:wpfResults = New-Object System.Collections.ObjectModel.ObservableCollection[object]
    $script:ctrl['DgResults'].ItemsSource = $script:wpfResults

    $script:currentProcess = $null
    $script:pendingByid    = @{}

    function Set-Status($message) { $script:ctrl['TxtStatus'].Text = $message }

    function Update-Summary {
        $c = ($script:wpfResults | Where-Object Status -eq 'CREATED').Count
        $s = ($script:wpfResults | Where-Object Status -eq 'SKIPPED').Count
        $f = ($script:wpfResults | Where-Object Status -eq 'FAILED' ).Count
        $parts = @()
        if ($c) { $parts += "$c created" }
        if ($s) { $parts += "$s skipped" }
        if ($f) { $parts += "$f failed" }
        $script:ctrl['TxtSummary'].Text = $parts -join '  |  '
    }

    function Invoke-UIDispatch {
        $script:wpfWindow.Dispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [action]{}
        )
    }

    function Find-NodeExe {
        try {
            $cmd = Get-Command node.exe -ErrorAction Stop
            if ($cmd -and $cmd.Source) { return $cmd.Source }
        } catch { }
        foreach ($p in @(
            "$env:ProgramFiles\nodejs\node.exe",
            "${env:ProgramFiles(x86)}\nodejs\node.exe",
            "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
        )) { if ($p -and (Test-Path $p)) { return $p } }
        return $null
    }

    function Import-ConnectionSettings {
        $local  = $null
        $shared = Read-SharedConfig
        if (Test-Path $script:connSettings) {
            try { $local = Get-Content $script:connSettings -Raw | ConvertFrom-Json } catch { }
        }
        $tn = if ($local.TenantName)      { $local.TenantName }      else { $shared.TenantName }
        $ts = if ($local.TenantSearch)    { $local.TenantSearch }    else { $shared.TenantSearch }
        $cn = if ($local.CredentialsName) { $local.CredentialsName } else { $shared.CredentialsName }
        if ($tn) { $script:ctrl['TxtTenantName'].Text      = $tn }
        if ($ts) { $script:ctrl['TxtTenantSearch'].Text    = $ts }
        if ($cn) { $script:ctrl['TxtCredentialsName'].Text = $cn }
    }

    function Save-Settings {
        try {
            $dir = Split-Path $script:connSettings
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            @{
                TenantName      = $script:ctrl['TxtTenantName'].Text
                TenantSearch    = $script:ctrl['TxtTenantSearch'].Text
                CredentialsName = $script:ctrl['TxtCredentialsName'].Text
            } | ConvertTo-Json | Set-Content $script:connSettings -Encoding UTF8
            Update-SharedConfig @{
                TenantName      = $script:ctrl['TxtTenantName'].Text
                TenantSearch    = $script:ctrl['TxtTenantSearch'].Text
                CredentialsName = $script:ctrl['TxtCredentialsName'].Text
            }
        } catch { }
    }

    function Add-PendingRow($id, $workload, $connectionName) {
        $row = [pscustomobject]@{
            Id             = $id
            Timestamp      = (Get-Date).ToString('HH:mm:ss')
            Workload       = $workload
            ConnectionName = $connectionName
            Status         = 'WORKING'
            Message        = 'queued'
        }
        $script:wpfResults.Add($row)
        $script:pendingByid[$id] = $row
        $script:ctrl['DgResults'].ScrollIntoView($row)
        Update-Summary
    }

    function Update-Row($id, $status, $message) {
        if ($script:pendingByid.ContainsKey($id)) {
            $row = $script:pendingByid[$id]
            $row.Timestamp = (Get-Date).ToString('HH:mm:ss')
            $row.Status    = $status
            $row.Message   = $message
            $script:ctrl['DgResults'].Items.Refresh()
            Update-Summary
        }
    }

    function Invoke-Connector {
        param(
            [Parameter(Mandatory)] [string]$Mode,
            [string[]]$StdinLines = @(),
            [string]$DisplayName = ''
        )

        $node = Find-NodeExe
        if (-not $node) {
            [System.Windows.MessageBox]::Show(
                "Node.js was not found on PATH.`n`nInstall Node 18+ from https://nodejs.org and reopen this GUI.",
                "Node.js missing",'OK','Error') | Out-Null
            return $false
        }
        if (-not (Test-Path $script:connectorJs)) {
            [System.Windows.MessageBox]::Show(
                "fly-connector.js not found next to this script.`n`nExpected: $script:connectorJs",
                "Connector missing",'OK','Error') | Out-Null
            return $false
        }

        $argList = @("`"$($script:connectorJs)`"", "--mode=$Mode")
        if ($DisplayName) {
            $clean    = ($DisplayName -replace '[^A-Za-z0-9._-]','_')
            $argList += "--display-name=$clean"
        }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $node
        $psi.WorkingDirectory       = $PSScriptRoot
        $psi.Arguments              = $argList -join ' '
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.RedirectStandardInput  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.EnableRaisingEvents = $true

        $stdoutHandler = {
            param($src, $e)
            if (-not $e.Data) { return }
            $line = $e.Data
            $script:wpfWindow.Dispatcher.Invoke([action]{
                Invoke-ConnectorLine $line
            })
        }
        $stderrHandler = {
            param($src, $e)
            if (-not $e.Data) { return }
            $line = $e.Data
            $script:wpfWindow.Dispatcher.Invoke([action]{
                Set-Status "stderr: $line"
            })
        }
        Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $stdoutHandler | Out-Null
        Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived  -Action $stderrHandler | Out-Null

        $script:currentProcess = $proc
        $null = $proc.Start()
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        foreach ($line in $StdinLines) { $proc.StandardInput.WriteLine($line) }
        $proc.StandardInput.Close()

        while (-not $proc.HasExited) {
            Invoke-UIDispatch
            Start-Sleep -Milliseconds 100
        }
        Start-Sleep -Milliseconds 250
        Invoke-UIDispatch

        Get-EventSubscriber | Where-Object SourceObject -eq $proc | Unregister-Event
        $script:currentProcess = $null
        return ($proc.ExitCode -eq 0)
    }

    function Invoke-ConnectorLine($line) {
        try { $obj = $line | ConvertFrom-Json -ErrorAction Stop } catch {
            Set-Status "(non-JSON) $line"
            return
        }
        if ($obj.event) {
            switch ($obj.event) {
                'info'     { Set-Status $obj.message }
                'warn'     { Set-Status "WARN: $($obj.message)" }
                'error'    { Set-Status "ERROR: $($obj.message)" }
                'fatal'    { Set-Status "FATAL: $($obj.message)" }
                'login-ok' { Set-Status "Signed in. $($obj.message)"; $script:ctrl['TxtAuthStatus'].Text = "Signed in. Session saved." }
                'done'     { Set-Status "Connector finished." }
                default    { Set-Status "$($obj.event): $($obj.message)" }
            }
            return
        }
        if ($obj.id -and $obj.status) {
            Update-Row $obj.id $obj.status $obj.message
            return
        }
    }

    $script:ctrl['BtnSignIn'].Add_Click({
        $script:ctrl['BtnSignIn'].IsEnabled = $false
        $script:ctrl['BtnCreate'].IsEnabled = $false
        Set-Status "Launching browser for Microsoft SSO sign-in..."
        $script:ctrl['TxtAuthStatus'].Text = "Signing in - complete the SSO flow in the Chrome window, then close it."
        try {
            Invoke-Connector -Mode 'login' | Out-Null
        } finally {
            $script:ctrl['BtnSignIn'].IsEnabled = $true
            $script:ctrl['BtnCreate'].IsEnabled = $true
        }
    })

    $script:ctrl['BtnClear'].Add_Click({
        $script:wpfResults.Clear()
        $script:pendingByid.Clear()
        Update-Summary
        Set-Status "Results cleared."
    })

    $script:ctrl['BtnOpenLogs'].Add_Click({
        $logsDir = Join-Path $PSScriptRoot 'logs'
        if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
        Start-Process explorer.exe $logsDir
        Set-Status "Opened: $logsDir"
    })

    $script:ctrl['BtnSaveLog'].Add_Click({
        if ($script:wpfResults.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Nothing to save.","Save Log",'OK','Information') | Out-Null
            return
        }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "CSV (*.csv)|*.csv"
        $tag = $script:ctrl['TxtTenantName'].Text
        if ([string]::IsNullOrWhiteSpace($tag)) { $tag = 'tenant' }
        $dlg.FileName = "fly-connections-$tag-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        if ($dlg.ShowDialog()) {
            $script:wpfResults | Select-Object Timestamp, Workload, ConnectionName, Status, Message |
                Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
            Set-Status "Log saved: $($dlg.FileName)"
        }
    })

    $script:ctrl['BtnCancel'].Add_Click({
        if ($script:currentProcess -and -not $script:currentProcess.HasExited) {
            try { $script:currentProcess.Kill() } catch { }
            Set-Status "Cancelled."
        }
    })

    $script:ctrl['BtnCreate'].Add_Click({
        $tenantName = $script:ctrl['TxtTenantName'].Text.Trim()
        $tenantSrch = $script:ctrl['TxtTenantSearch'].Text.Trim()
        $credName   = $script:ctrl['TxtCredentialsName'].Text.Trim()

        if ([string]::IsNullOrWhiteSpace($tenantName) -or [string]::IsNullOrWhiteSpace($tenantSrch) -or [string]::IsNullOrWhiteSpace($credName)) {
            [System.Windows.MessageBox]::Show("Enter Display Name, Search Code, and Credentials Name.","Validation",'OK','Warning') | Out-Null
            return
        }

        $selected = $script:connSvcDef | Where-Object { $script:ctrl[$_.CheckboxName].IsChecked }
        if (-not $selected) {
            [System.Windows.MessageBox]::Show("Select at least one workload.","Validation",'OK','Warning') | Out-Null
            return
        }

        Save-Settings

        $tasks = @()
        foreach ($svc in $selected) {
            $id   = [guid]::NewGuid().ToString('N').Substring(0,8)
            $name = "$tenantName - $($svc.Label)"
            $tasks += [pscustomobject]@{
                id              = $id
                tenantName      = $tenantName
                tenantSearch    = $tenantSrch
                workloadLabel   = $svc.Label
                connectionName  = $name
                credentialsName = $credName
            }
            Add-PendingRow $id $svc.Label $name
        }

        $stdinLines = $tasks | ForEach-Object { $_ | ConvertTo-Json -Compress }

        $script:ctrl['BtnCreate'].IsEnabled = $false
        $script:ctrl['BtnSignIn'].IsEnabled = $false
        $script:ctrl['BtnCancel'].IsEnabled = $true

        $labelToKey = @{
            'Exchange Online'       = 'Exchange'
            'SharePoint Online'     = 'SharePoint'
            'OneDrive'              = 'OneDrive'
            'Microsoft Teams'       = 'Teams'
            'Microsoft Teams Chat'  = 'Teams Chat'
            'Microsoft 365 Groups'  = 'Groups'
        }

        Set-Status "Driving the AOS portal..."
        try {
            $ok = Invoke-Connector -Mode 'create' -StdinLines $stdinLines -DisplayName $tenantName

            $workloadsJsonPath = Join-Path $PSScriptRoot 'workloads.json'
            $wlJson = if (Test-Path $workloadsJsonPath) {
                try { Get-Content $workloadsJsonPath -Raw | ConvertFrom-Json } catch { [pscustomobject]@{} }
            } else { [pscustomobject]@{} }

            $connKeyName = if ($script:ctrl['RdoSource'].IsChecked) { 'Source' } else { 'Destination' }
            $updated = 0
            foreach ($task in $tasks) {
                $row = $script:pendingByid[$task.id]
                if ($row -and $row.Status -eq 'CREATED') {
                    $key = $labelToKey[$task.workloadLabel]
                    if ($key) {
                        if (-not $wlJson.PSObject.Properties[$key]) {
                            $wlJson | Add-Member -NotePropertyName $key -NotePropertyValue ([pscustomobject]@{ Policy = ""; Source = ""; Destination = "" })
                        }
                        $wlJson.$key.$connKeyName = $task.connectionName
                        $updated++
                    }
                }
            }
            if ($updated -gt 0) {
                $wlJson | ConvertTo-Json -Depth 3 | Set-Content $workloadsJsonPath -Encoding UTF8
            }

            $summary = if ($ok) { "Done - $tenantName complete." } else { "Finished with errors." }
            if ($updated -gt 0) { $summary += "  $updated $connKeyName connection(s) written to workloads.json." }
            Set-Status $summary
        } finally {
            $script:ctrl['BtnCreate'].IsEnabled = $true
            $script:ctrl['BtnSignIn'].IsEnabled = $true
            $script:ctrl['BtnCancel'].IsEnabled = $false
        }
    })

    $script:ctrl['BtnClose'].Add_Click({ $script:wpfWindow.Close() })

    Import-ConnectionSettings
    Update-Summary

    $node = Find-NodeExe
    if (-not $node) {
        $script:ctrl['TxtAuthStatus'].Text = "Node.js not found on PATH. Install Node 18+ from https://nodejs.org."
        Set-Status "Node.js missing - install Node 18+ and reopen."
    } elseif (-not (Test-Path $script:connectorJs)) {
        $script:ctrl['TxtAuthStatus'].Text = "fly-connector.js not found next to this script."
        Set-Status "Place fly-connector.js + package.json next to this script and run 'npm install' there."
    } else {
        $authFile = Join-Path $PSScriptRoot 'auth\storageState.json'
        if (Test-Path $authFile) {
            $script:ctrl['TxtAuthStatus'].Text = "Previous session found. Sign in again only if it has expired."
        }
        Set-Status "Ready"
    }

    [void]$script:wpfWindow.ShowDialog()
}

# ═════════════════════════════════════════════════════════════════════════════
# MIGRATION RUNNER
# ═════════════════════════════════════════════════════════════════════════════
function Show-MigrationRunnerForm {

    $WorkloadDefs = [ordered]@{
        SharePoint   = @{ Import = "Import-FlySharePointMappings";  Start = "Start-FlySharePointMigration";  PreScan = "Start-FlySharePointPreScan";  Verify = "Start-FlySharePointVerification";  Status = "Export-FlySharePointMappingStatus";  Report = "Export-FlySharePointMigrationReport";  PolicyType = "SharePoint" }
        Exchange     = @{ Import = "Import-FlyExchangeMappings";    Start = "Start-FlyExchangeMigration";    PreScan = "Start-FlyExchangePreScan";    Verify = "Start-FlyExchangeVerification";    Status = "Export-FlyExchangeMappingStatus";    Report = "Export-FlyExchangeMigrationReport";    PolicyType = "Exchange"   }
        OneDrive     = @{ Import = "Import-FlyOneDriveMappings";    Start = "Start-FlyOneDriveMigration";    PreScan = "Start-FlyOneDrivePreScan";    Verify = "Start-FlyOneDriveVerification";    Status = "Export-FlyOneDriveMappingStatus";    Report = "Export-FlyOneDriveMigrationReport";    PolicyType = "OneDrive"   }
        Teams        = @{ Import = "Import-FlyTeamsMappings";       Start = "Start-FlyTeamsMigration";       PreScan = "Start-FlyTeamsPreScan";       Verify = "Start-FlyTeamsVerification";       Status = "Export-FlyTeamsMappingStatus";       Report = "Export-FlyTeamsMigrationReport";       PolicyType = "Teams"      }
        'Teams Chat' = @{ Import = "Import-FlyTeamChatMappings";    Start = "Start-FlyTeamChatMigration";    PreScan = "";                            Verify = "Start-FlyTeamChatVerification";    Status = "Export-FlyTeamChatMappingStatus";    Report = "Export-FlyTeamChatMigrationReport";    PolicyType = "TeamChat"   }
        Groups       = @{ Import = "Import-FlyM365GroupMappings";   Start = "Start-FlyM365GroupMigration";   PreScan = "Start-FlyM365GroupPreScan";   Verify = "Start-FlyM365GroupVerification";   Status = "Export-FlyM365GroupMappingStatus";   Report = "Export-FlyM365GroupMigrationReport";   PolicyType = "M365Group"  }
    }

    $script:ConfigPath         = Join-Path $env:APPDATA "FlyMigration\config.json"
    $script:WorkloadConfigPath = Join-Path $PSScriptRoot "workloads.json"
    $script:LogDir             = Join-Path $PSScriptRoot "logs"
    $script:LogFile            = Join-Path $script:LogDir ("FlyRunner_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    if (-not (Test-Path $script:LogDir)) { New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null }

    function Save-FlyConfig {
        param([string]$Url, [string]$ClientId, [string]$ClientSecret)
        $dir = Split-Path $script:ConfigPath
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $encSecret = $ClientSecret | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString
        @{ Url = $Url; ClientId = $ClientId; EncSecret = $encSecret } |
            ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
    }

    function Read-WorkloadConfig {
        if (-not (Test-Path $script:WorkloadConfigPath)) {
            [ordered]@{
                SharePoint   = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
                Exchange     = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
                OneDrive     = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
                Teams        = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
                'Teams Chat' = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
                Groups       = [ordered]@{ Policy = ""; Source = ""; Destination = "" }
            } | ConvertTo-Json -Depth 3 | Set-Content $script:WorkloadConfigPath -Encoding UTF8
        }
        try   { return Get-Content $script:WorkloadConfigPath -Raw | ConvertFrom-Json }
        catch { return [pscustomobject]@{} }
    }

    function Save-WorkloadConfig {
        try {
            $cfg = Read-WorkloadConfig
            foreach ($wl in $script:WLControls.Keys) {
                $ctrl = $script:WLControls[$wl]
                $s = $ctrl.Src.Text.Trim()
                $d = $ctrl.Dest.Text.Trim()
                if (-not $cfg.PSObject.Properties[$wl]) {
                    $cfg | Add-Member -NotePropertyName $wl -NotePropertyValue ([pscustomobject]@{ Policy = ""; Source = ""; Destination = "" })
                }
                if ($s) { $cfg.$wl.Source      = $s }
                if ($d) { $cfg.$wl.Destination = $d }
            }
            $cfg | ConvertTo-Json -Depth 3 | Set-Content $script:WorkloadConfigPath -Encoding UTF8
            Write-Log "Workload config saved to: $(Split-Path $script:WorkloadConfigPath -Leaf)" "OK"
        } catch {
            Write-Log "Save failed: $($_.Exception.Message)" "ERROR"
        }
    }

    function Get-FlyConfig {
        if (-not (Test-Path $script:ConfigPath)) { return $null }
        try {
            $cfg    = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
            $secure = $cfg.EncSecret | ConvertTo-SecureString
            $bstr   = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            $plain  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            return @{ Url = $cfg.Url; ClientId = $cfg.ClientId; ClientSecret = $plain }
        }
        catch { return $null }
    }

    $Form = New-Object System.Windows.Forms.Form
    $Form.Text            = "AvePoint Fly - Migration Runner"
    $Form.WindowState     = [System.Windows.Forms.FormWindowState]::Maximized
    $Form.StartPosition   = [System.Windows.Forms.FormStartPosition]::WindowsDefaultBounds
    $Form.BackColor       = $clrBg
    $Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $Form.MinimumSize     = [System.Drawing.Size]::new(960, 860)
    $Form.Font            = $FontBody

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Height    = 46; $hdr.Dock = [System.Windows.Forms.DockStyle]::Top
    $hdr.BackColor = $clrAccent
    $Form.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 30
    $hdrTitle = New-Object System.Windows.Forms.Label
    $hdrTitle.Text      = "  Migration Runner"
    $hdrTitle.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
    $hdrTitle.ForeColor = [System.Drawing.Color]::White
    $hdrTitle.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrTitle.Size      = [System.Drawing.Size]::new($Form.Width - $_hdrX, 46)
    $hdrTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdrTitle.Anchor    = $AnchorTLR
    $hdr.Controls.Add($hdrTitle)

    $tlp = New-Object System.Windows.Forms.TableLayoutPanel
    $tlp.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $tlp.ColumnCount = 1
    $tlp.RowCount    = 5
    $tlp.Padding     = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
    $tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 136))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,  88))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 320))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,  54))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,  100))) | Out-Null
    $Form.Controls.Add($tlp)

    # STEP 1 - FLY AUTH
    $c1 = New-CardPanel "STEP 1  -  FLY AUTHENTICATION"
    $tlp.Controls.Add($c1.Parent, 0, 0)

    New-Lbl $c1 "Fly API URL" 16 28 | Out-Null
    $tbFlyUrl = New-TB $c1 16 44 860 -RightMargin 20

    New-Lbl $c1 "AOS Client ID" 16 76 | Out-Null
    $lblSecret  = New-Lbl $c1 "Client Secret" 320 76
    $tbFlyId    = New-TB $c1 16  94 290
    $tbFlyPass  = New-TB $c1 320 94 280 -Password $true
    $btnFlyConn = New-Btn $c1 "Connect" 616 92 90 28
    $dotFly     = New-Dot $c1 714 98

    $c1.Add_SizeChanged({
        $margin  = 16; $btnW = 90; $dotW = 22; $gap = 8
        $usable  = $c1.Width - $margin * 2
        $fieldW  = [Math]::Max(120, [int](($usable - $btnW - $dotW - $gap * 4) / 2))
        $tbFlyUrl.Width     = $c1.Width - $margin - 20
        $tbFlyId.Left       = $margin
        $tbFlyId.Width      = $fieldW
        $lblSecret.Left     = $margin + $fieldW + $gap
        $tbFlyPass.Left     = $margin + $fieldW + $gap
        $tbFlyPass.Width    = $fieldW
        $btnFlyConn.Left    = $margin + $fieldW * 2 + $gap * 2
        $btnFlyConn.Width   = $btnW
        $dotFly.Left        = $btnFlyConn.Left + $btnW + $gap
    })

    # STEP 2 - PROJECT CONFIG
    $c2 = New-CardPanel "STEP 2  -  PROJECT CONFIGURATION"
    $tlp.Controls.Add($c2.Parent, 0, 1)

    New-Lbl $c2 "Customer Prefix" 16 28 | Out-Null
    $tbPrefix = New-TB $c2 16 45 192

    $chkCreateProject = New-Object System.Windows.Forms.CheckBox
    $chkCreateProject.Text     = "Create project if not exists"
    $chkCreateProject.Font     = $FontBody
    $chkCreateProject.Location = [System.Drawing.Point]::new(0, 48)
    $chkCreateProject.Size     = [System.Drawing.Size]::new(230, 24)
    $chkCreateProject.Checked  = $true
    $chkCreateProject.Anchor   = $AnchorTR
    $c2.Controls.Add($chkCreateProject)

    $c2.Add_SizeChanged({ $chkCreateProject.Left = $c2.Width - 238 })

    # STEP 3 - WORKLOADS
    $c3 = New-CardPanel "STEP 3  -  WORKLOADS"
    $tlp.Controls.Add($c3.Parent, 0, 2)

    $chkAll = New-Object System.Windows.Forms.CheckBox
    $chkAll.Text      = "Workload"; $chkAll.Font = $FontBold; $chkAll.ForeColor = $clrText
    $chkAll.Location  = [System.Drawing.Point]::new(16, 27)
    $chkAll.Size      = [System.Drawing.Size]::new(155, 20)
    $chkAll.Checked   = $true; $chkAll.Anchor = $AnchorTL
    $c3.Controls.Add($chkAll)
    New-Lbl $c3 "CSV File"    182  30 $true | Out-Null
    New-Lbl $c3 "Source"        0  30 $true | Out-Null
    New-Lbl $c3 "Destination"   0  30 $true | Out-Null
    New-Lbl $c3 "Operation"     0  30 $true | Out-Null
    New-Lbl $c3 "Status"        0  30 $true | Out-Null

    $lblSrcHdr = $c3.Controls | Where-Object { $_.Text -eq "Source" }
    $lblDstHdr = $c3.Controls | Where-Object { $_.Text -eq "Destination" }
    $lblOpHdr  = $c3.Controls | Where-Object { $_.Text -eq "Operation" }
    $lblDotHdr = $c3.Controls | Where-Object { $_.Text -eq "Status" }

    New-HSep $c3 16 50 16

    $script:WLControls = [ordered]@{}
    $i = 0
    foreach ($wl in $WorkloadDefs.Keys) {
        $y = 60 + ($i * 40)

        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = $wl; $chk.Font = $FontBold
        $chk.Location = [System.Drawing.Point]::new(16, $y)
        $chk.Size     = [System.Drawing.Size]::new(155, 24)
        $chk.Checked  = $true; $chk.Anchor = $AnchorTL
        $c3.Controls.Add($chk)

        $tbCsv = New-Object System.Windows.Forms.TextBox
        $tbCsv.Location    = [System.Drawing.Point]::new(182, $y)
        $tbCsv.Size        = [System.Drawing.Size]::new(400, 24)
        $tbCsv.Font        = $FontBody
        $tbCsv.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $tbCsv.Text        = "No file selected"
        $tbCsv.ForeColor   = [System.Drawing.Color]::FromArgb(90, 90, 90)
        $tbCsv.Anchor      = $AnchorTLR
        $c3.Controls.Add($tbCsv)

        $btnBrowse = New-Object System.Windows.Forms.Button
        $btnBrowse.Text      = "Browse..."
        $btnBrowse.Font      = $FontBold
        $btnBrowse.Size      = [System.Drawing.Size]::new(76, 26)
        $btnBrowse.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnBrowse.FlatAppearance.BorderSize = 0
        $btnBrowse.BackColor = [System.Drawing.Color]::FromArgb(225, 228, 238)
        $btnBrowse.ForeColor = $clrText
        $btnBrowse.Anchor    = $AnchorTL
        $btnBrowse.Location  = [System.Drawing.Point]::new(0, $y)
        $capturedCsv = $tbCsv
        $capturedWl  = $wl
        $btnBrowse.Add_Click({
            $d = New-Object System.Windows.Forms.OpenFileDialog
            $d.Filter = "CSV files (*.csv)|*.csv"
            $d.Title  = "Select $capturedWl mapping CSV"
            if ($d.ShowDialog() -eq 'OK') {
                $capturedCsv.Tag       = $d.FileName
                $capturedCsv.ForeColor = $clrText
                try {
                    $rowCount = (Import-Csv $d.FileName | Measure-Object).Count
                    $capturedCsv.Text = "$(Split-Path $d.FileName -Leaf)  ($rowCount rows)"
                } catch {
                    $capturedCsv.Text = $d.FileName
                }
            }
        }.GetNewClosure())
        $c3.Controls.Add($btnBrowse)

        $cmbSrc = New-Object System.Windows.Forms.TextBox
        $cmbSrc.Font = $FontBody; $cmbSrc.Size = [System.Drawing.Size]::new(160, 24)
        $cmbSrc.Location = [System.Drawing.Point]::new(0, $y)
        $cmbSrc.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $cmbSrc.BackColor = $clrPanel
        $cmbSrc.Anchor = $AnchorTR
        $c3.Controls.Add($cmbSrc)

        $cmbDest = New-Object System.Windows.Forms.TextBox
        $cmbDest.Font = $FontBody; $cmbDest.Size = [System.Drawing.Size]::new(160, 24)
        $cmbDest.Location = [System.Drawing.Point]::new(0, $y)
        $cmbDest.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $cmbDest.BackColor = $clrPanel
        $cmbDest.Anchor = $AnchorTR
        $c3.Controls.Add($cmbDest)

        $cmbOp = New-Object System.Windows.Forms.ComboBox
        $cmbOp.Font = $FontBody; $cmbOp.Size = [System.Drawing.Size]::new(120, 24)
        $cmbOp.Location = [System.Drawing.Point]::new(0, $y)
        $cmbOp.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $cmbOp.Anchor = $AnchorTR
        @("Import Only","Verification","Pre-Scan","Migration","Report") | ForEach-Object { $cmbOp.Items.Add($_) | Out-Null }
        $cmbOp.SelectedIndex = 0
        $c3.Controls.Add($cmbOp)

        $dot = New-Object System.Windows.Forms.Label
        $dot.Text = [char]0x25CF; $dot.Font = New-Object System.Drawing.Font("Segoe UI", 13)
        $dot.ForeColor = $clrGrey; $dot.AutoSize = $true
        $dot.Location = [System.Drawing.Point]::new(0, $y); $dot.Anchor = $AnchorTR
        $c3.Controls.Add($dot)

        $script:WLControls[$wl] = @{ Check = $chk; CSV = $tbCsv; Browse = $btnBrowse; Src = $cmbSrc; Dest = $cmbDest; Operation = $cmbOp; Dot = $dot; Y = $y }
        $i++
    }

    $chkAll.Add_CheckedChanged({
        foreach ($wl in $script:WLControls.Keys) {
            $script:WLControls[$wl].Check.Checked = $chkAll.Checked
        }
    }.GetNewClosure())

    $ySep = 60 + ($WorkloadDefs.Count * 40) + 4
    New-HSep $c3 16 $ySep 16
    $yOut = $ySep + 10
    New-Lbl $c3 "Report folder:" 16 $yOut | Out-Null
    $tbOutFolder  = New-TB $c3 110 ($yOut - 2) 400 180
    $btnOutBrowse = New-Btn $c3 "Browse..." 0 ($yOut - 4) 76 26 $false $true
    $btnOutBrowse.Left = $c3.Width - 84
    $btnOutBrowse.Add_Click({
        $fd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fd.SelectedPath = $tbOutFolder.Text
        if ($fd.ShowDialog() -eq "OK") { $tbOutFolder.Text = $fd.SelectedPath }
    })
    $tbOutFolder.Text = "$env:USERPROFILE\Desktop"

    $c3.Add_SizeChanged({
        $rightEdge  = $c3.Width - 16
        $dotW = 22; $opW = 128; $connW = 160; $browseW = 76
        $dotLeft    = $rightEdge - $dotW
        $opLeft     = $dotLeft   - 6 - $opW
        $dstLeft    = $opLeft    - 8 - $connW
        $srcLeft    = $dstLeft   - 8 - $connW
        $browseLeft = $srcLeft   - 8 - $browseW
        $lblSrcHdr.Left = $srcLeft; $lblDstHdr.Left = $dstLeft
        $lblOpHdr.Left  = $opLeft;  $lblDotHdr.Left = $dotLeft
        foreach ($wl in $script:WLControls.Keys) {
            $wlCtrl = $script:WLControls[$wl]
            $wlCtrl.Dot.Left        = $dotLeft
            $wlCtrl.Operation.Left  = $opLeft;  $wlCtrl.Operation.Width = $opW
            $wlCtrl.Dest.Left       = $dstLeft; $wlCtrl.Dest.Width      = $connW
            $wlCtrl.Src.Left        = $srcLeft; $wlCtrl.Src.Width       = $connW
            $wlCtrl.Browse.Left     = $browseLeft
            $wlCtrl.CSV.Width       = $wlCtrl.Browse.Left - $wlCtrl.CSV.Left - 6
        }
        $btnOutBrowse.Left = $rightEdge - 80
        $tbOutFolder.Width = $btnOutBrowse.Left - $tbOutFolder.Left - 6
    })

    # RUN ROW
    $c4 = New-CardPanel ""
    $tlp.Controls.Add($c4.Parent, 0, 3)

    $btnRun = New-Btn $c4 "Run Selected Workloads" 16 12 200 30
    $btnRun.Enabled = $false

    $btnSaveConfig = New-Btn $c4 "Save Connections" 228 12 148 30 $false
    $btnSaveConfig.Add_Click({ Save-WorkloadConfig })

    $lblRunStatus = New-Object System.Windows.Forms.Label
    $lblRunStatus.Location  = [System.Drawing.Point]::new(388, 18)
    $lblRunStatus.AutoSize  = $false
    $lblRunStatus.Font      = $FontBody
    $lblRunStatus.ForeColor = $clrMuted
    $lblRunStatus.Text      = "Connect to Fly first"
    $lblRunStatus.Anchor    = $AnchorTLR
    $c4.Controls.Add($lblRunStatus)

    $btnClose = New-Btn $c4 "Close" 0 12 100 30 $false $true
    $btnClose.Add_Click({ $Form.Close() })

    $c4.Add_SizeChanged({
        $btnClose.Left      = $c4.Width - 108
        $lblRunStatus.Width = $btnClose.Left - 400 - 8
    })

    # LOG
    $c5 = New-CardPanel "LOG"
    $tlp.Controls.Add($c5.Parent, 0, 4)

    $script:rtbLog = New-Object System.Windows.Forms.RichTextBox
    $script:rtbLog.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $script:rtbLog.Font        = $FontMono
    $script:rtbLog.BackColor   = $clrLogBg
    $script:rtbLog.ForeColor   = [System.Drawing.Color]::FromArgb(190, 210, 255)
    $script:rtbLog.ReadOnly    = $true
    $script:rtbLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $script:rtbLog.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $script:rtbLog.Margin      = New-Object System.Windows.Forms.Padding(16, 26, 8, 8)
    $c5.Controls.Add($script:rtbLog)

    # EVENTS
    $btnFlyConn.Add_Click({
        $btnFlyConn.Enabled = $false
        $dotFly.ForeColor   = $clrGrey
        try {
            $flyUrl = $tbFlyUrl.Text.Trim()
            $flyId  = $tbFlyId.Text.Trim()
            $flyPw  = $tbFlyPass.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($flyId) -or [string]::IsNullOrWhiteSpace($flyPw)) {
                throw "Client ID and Secret are required."
            }
            Write-Log "Connecting to Fly..."
            if (-not (Get-Module -Name Fly.Client -ListAvailable)) {
                throw "Fly.Client module not found. Run: Install-Module Fly.Client -Scope CurrentUser"
            }
            Import-Module Fly.Client -ErrorAction Stop
            Connect-Fly -Url $flyUrl -ClientId $flyId -ClientSecret $flyPw -ErrorAction Stop
            Save-FlyConfig -Url $flyUrl -ClientId $flyId -ClientSecret $flyPw
            Write-Log "Credentials saved for next run." "OK"
            Write-Log "Testing API endpoint..."
            try {
                Get-FlyMigrationProject -Top 1 -ErrorAction Stop | Out-Null
                Write-Log "API endpoint reachable OK" "OK"
            } catch {
                $testErr = $_.Exception.Message
                if ($testErr -like "*404*" -or $testErr -like "*Not Found*") {
                    Write-Log "API test returned 404 - your Fly API URL may be wrong." "WARN"
                    Write-Log "Expected format: https://graph.avepointonlineservices.com/fly" "WARN"
                    Write-Log "Find the correct URL in the Fly user guide under Public API." "WARN"
                } else {
                    Write-Log "API test warning: $testErr" "WARN"
                }
            }
            Write-Log "Connections pre-loaded from workloads.json" "OK"
            $dotFly.ForeColor       = $clrGreen
            $btnRun.Enabled         = $true
            $lblRunStatus.Text      = "Ready"
            $lblRunStatus.ForeColor = $clrGreen
            Write-Log "Connected to Fly OK" "OK"
        }
        catch {
            $dotFly.ForeColor   = $clrRed
            $btnFlyConn.Enabled = $true
            Write-Log "Connection failed: $($_.Exception.Message)" "ERROR"
        }
    })

    $btnRun.Add_Click({
        $btnRun.Enabled = $false
        $prefix     = $tbPrefix.Text.Trim()
        $outFolder  = $tbOutFolder.Text.Trim()
        $createProj = $chkCreateProject.Checked

        if ([string]::IsNullOrWhiteSpace($prefix)) { Write-Log "Customer Prefix is required." "ERROR"; $btnRun.Enabled = $true; return }

        $ok = 0; $fail = 0

        $RequiredCsvCols = @{
            SharePoint   = @('Source URL', 'Source object level', 'Destination URL', 'Destination object level')
            Exchange     = @('Source', 'Source type', 'Destination', 'Destination type')
            OneDrive     = @('Source user', 'Destination user')
            Teams        = @('Source Team name', 'Source Team email address', 'Destination Team name', 'Destination Team email address')
            'Teams Chat' = @('Source user', 'Destination user')
            Groups       = @('Source Group name', 'Source Group email address', 'Destination Group name', 'Destination Group email address')
        }

        foreach ($wl in $script:WLControls.Keys) {
            $wlCtrl    = $script:WLControls[$wl]
            if (-not $wlCtrl.Check.Checked) { continue }

            $csvPath   = if ($wlCtrl.CSV.Tag) { $wlCtrl.CSV.Tag } else { $wlCtrl.CSV.Text.Trim() }
            $operation = $wlCtrl.Operation.SelectedItem
            $srcConn   = $wlCtrl.Src.Text.Trim()
            $dstConn   = $wlCtrl.Dest.Text.Trim()
            $policy    = [string]($script:WorkloadConfig.$wl.Policy)
            $cmds      = $WorkloadDefs[$wl]
            $projName  = "$prefix - $wl"

            if ([string]::IsNullOrWhiteSpace($srcConn)) {
                $wlCtrl.Dot.ForeColor = $clrRed
                Write-Log "$wl - no source connection set, skipping" "WARN"; $fail++; continue
            }
            if ([string]::IsNullOrWhiteSpace($dstConn)) {
                $wlCtrl.Dot.ForeColor = $clrRed
                Write-Log "$wl - no destination connection set, skipping" "WARN"; $fail++; continue
            }
            if ($csvPath -eq "No file selected" -or -not (Test-Path $csvPath)) {
                $wlCtrl.Dot.ForeColor = $clrRed
                Write-Log "$wl - no valid CSV selected, skipping" "WARN"; $fail++; continue
            }

            $reqCols = $RequiredCsvCols[$wl]
            if ($reqCols) {
                try {
                    $csvRows = Import-Csv $csvPath
                    if (-not $csvRows) {
                        $wlCtrl.Dot.ForeColor = $clrRed
                        Write-Log "$wl CSV has no data rows." "ERROR"; $fail++; continue
                    }
                    $csvHeaders = ($csvRows | Select-Object -First 1).PSObject.Properties.Name
                    $missingCols = $reqCols | Where-Object { $csvHeaders -notcontains $_ }
                    if ($missingCols) {
                        $wlCtrl.Dot.ForeColor = $clrRed
                        Write-Log "$wl CSV missing required columns: $($missingCols -join ', ')" "ERROR"
                        Write-Log "  Required for ${wl}: $($reqCols -join ', ')" "WARN"
                        $fail++; continue
                    }
                    if ($wl -eq 'Exchange') {
                        $badRows = @($csvRows | Where-Object { [string]::IsNullOrWhiteSpace($_.'Source type') -or [string]::IsNullOrWhiteSpace($_.'Destination type') })
                        if ($badRows.Count -gt 0) {
                            $wlCtrl.Dot.ForeColor = $clrRed
                            Write-Log "$wl CSV has $($badRows.Count) row(s) with empty 'Source type' or 'Destination type'." "ERROR"
                            Write-Log "  Valid types: User mailbox, Archive mailbox, Shared mailbox, Resource mailbox," "WARN"
                            Write-Log "  Distribution list, Mail-enabled security group, Microsoft 365 Group mailbox, Microsoft 365 Group" "WARN"
                            $fail++; continue
                        }
                    }
                    if ($wl -in @('OneDrive', 'Teams Chat')) {
                        $sameRows = @($csvRows | Where-Object { $_.'Source user' -eq $_.'Destination user' -and -not [string]::IsNullOrWhiteSpace($_.'Source user') })
                        if ($sameRows.Count -gt 0) {
                            $wlCtrl.Dot.ForeColor = $clrRed
                            Write-Log "$wl CSV has $($sameRows.Count) row(s) where Source user equals Destination user." "ERROR"
                            Write-Log "  The Fly API requires source and destination identities to be different." "WARN"
                            $fail++; continue
                        }
                    }
                    if ($wl -eq 'Groups') {
                        $sameRows = @($csvRows | Where-Object { $_.'Source Group email address' -eq $_.'Destination Group email address' -and -not [string]::IsNullOrWhiteSpace($_.'Source Group email address') })
                        if ($sameRows.Count -gt 0) {
                            $wlCtrl.Dot.ForeColor = $clrRed
                            Write-Log "$wl CSV has $($sameRows.Count) row(s) where Source Group email equals Destination Group email." "ERROR"
                            Write-Log "  The Fly API requires source and destination identities to be different." "WARN"
                            $fail++; continue
                        }
                    }
                } catch {
                    $wlCtrl.Dot.ForeColor = $clrRed
                    Write-Log "$wl CSV validation failed: $($_.Exception.Message)" "ERROR"
                    $fail++; continue
                }
            }

            $wlCtrl.Dot.ForeColor = $clrAmber
            [System.Windows.Forms.Application]::DoEvents()
            Write-Log "-- $wl [$operation] --"

            try {
                if ($createProj) {
                    $existing = Get-FlyMigrationProject -Name $projName -ErrorAction SilentlyContinue
                    if ($existing) {
                        Write-Log "Project exists: $projName"
                    } elseif ([string]::IsNullOrWhiteSpace($policy)) {
                        Write-Log "$wl - no policy set in workloads.json, cannot create project" "WARN"
                    } else {
                        Write-Log "Creating project: $projName..."
                        try {
                            New-FlyMigrationProject -Name $projName -SourceConnection $srcConn -DestinationConnection $dstConn -Policy $policy -ErrorAction Stop | Out-Null
                            Write-Log "Project created OK" "OK"
                        } catch {
                            Write-Log "Project creation failed: $($_.Exception.Message)" "WARN"
                            $verifyExist = Get-FlyMigrationProject -Name $projName -ErrorAction SilentlyContinue
                            if (-not $verifyExist) {
                                Write-Log "$wl - project does not exist and could not be created, skipping" "ERROR"
                                Write-Log "  Check the '$wl' policy name in workloads.json matches exactly what is in Fly" "WARN"
                                $wlCtrl.Dot.ForeColor = $clrRed
                                $fail++
                                continue
                            }
                            Write-Log "Project found - continuing despite creation warning" "WARN"
                        }
                    }
                }

                $statusFile = Join-Path $outFolder ($projName + "_MappingStatus_" + (Get-Date -Format "yyyyMMdd-HHmm") + ".csv")
                $errIdxBefore = $Error.Count
                Write-Log "Importing mappings from: $(Split-Path $csvPath -Leaf)..."
                & $cmds.Import -Project $projName -Path $csvPath -ErrorAction Stop
                Write-Log "Mappings imported OK" "OK"

                Write-Log "Exporting mapping status..."
                & $cmds.Status -Project $projName -OutFile $statusFile -ErrorAction Stop
                Write-Log "Mapping status saved: $(Split-Path $statusFile -Leaf)" "OK"

                if      ($operation -eq "Verification") { Write-Log "Starting verification..."; & $cmds.Verify  -Project $projName -ErrorAction Stop; Write-Log "Verification started OK" "OK" }
                elseif  ($operation -eq "Pre-Scan")     { if ($cmds.PreScan) { Write-Log "Starting pre-scan..."; & $cmds.PreScan -Project $projName -ErrorAction Stop; Write-Log "Pre-scan started OK" "OK" } else { Write-Log "$wl does not support Pre-Scan, skipping" "WARN" } }
                elseif  ($operation -eq "Migration")    { Write-Log "Starting migration...";    & $cmds.Start   -Project $projName -ErrorAction Stop; Write-Log "Migration started OK" "OK" }
                elseif  ($operation -eq "Report")       {
                    $reportFile = Join-Path $outFolder ($projName + "_MigrationReport_" + (Get-Date -Format "yyyyMMdd-HHmm") + ".csv")
                    Write-Log "Exporting migration report..."
                    & $cmds.Report -Project $projName -OutFile $reportFile -ErrorAction Stop
                    Write-Log "Report saved: $(Split-Path $reportFile -Leaf)" "OK"
                }

                $wlCtrl.Dot.ForeColor = $clrGreen
                $ok++
            }
            catch {
                $wlCtrl.Dot.ForeColor = $clrRed
                $errMsg = $_.Exception.Message
                if ($errMsg -like "*Additional text encountered after finished reading JSON content*") {
                    Write-Log "$wl failed: API returned an unparseable response (likely a 404 from a wrong base URL)." "ERROR"
                    Write-Log "Verify your Fly API URL in Step 1 - it should end with /fly (e.g. https://graph.avepointonlineservices.com/fly)." "WARN"
                } elseif ($errMsg -like "*404*" -or $errMsg -like "*Not Found*") {
                    Write-Log "$wl failed: 404 Not Found - check your Fly API URL in Step 1." "ERROR"
                } else {
                    Write-Log "$wl failed: $errMsg" "ERROR"
                    # Scan errors added during this import for the API response body (PS7 populates ErrorDetails.Message)
                    $apiLogged = $false
                    $newErrCount = $Error.Count - $errIdxBefore
                    for ($ei = 0; $ei -lt [Math]::Min($newErrCount, 8); $ei++) {
                        $ed = $Error[$ei].ErrorDetails.Message
                        if ($ed) {
                            try {
                                $j = $ed | ConvertFrom-Json -ErrorAction Stop
                                $apiMsg = if ($j.errorMessage) { $j.errorMessage.Trim() } `
                                          elseif ($j.ErrorMessage) { $j.ErrorMessage.Trim() } `
                                          else { $ed.Trim() }
                                Write-Log "  API: $apiMsg" "WARN"
                                if ($apiMsg -like "*already exist*" -or $apiMsg -like "*duplicate*" -or $apiMsg -like "*ProjectMappingDuplicated*") {
                                    Write-Log "  Hint: mappings already imported - delete '$projName' in Fly and re-run." "WARN"
                                }
                            } catch {
                                Write-Log "  API: $($ed.Trim())" "WARN"
                            }
                            $apiLogged = $true
                            break
                        }
                    }
                    if (-not $apiLogged) {
                        if ($wl -eq 'OneDrive' -and $errMsg -like "*(400)*") {
                            Write-Log "  API: Source and destination identity should be different." "WARN"
                            Write-Log "  Check OneDriveMappingFile.csv - each row's 'Source user' and 'Destination user' must be different accounts." "WARN"
                        } elseif ($errMsg -like "*(500)*" -or $errMsg -like "*Internal Server Error*") {
                            Write-Log "  Hint: 500 on import often means mappings already exist - delete '$projName' in Fly and re-run." "WARN"
                        }
                    }
                }
                $fail++
            }
        }

        Write-Log "------------------------------------------------"
        Write-Log "$ok workload$(if($ok -ne 1){'s'}) completed - $fail failed." "OK"
        $btnRun.Enabled = $true
    })

    # LAUNCH
    Write-Log "Ready - connect to Fly, configure project settings, then run."
    Write-Log "Log file: $($script:LogFile)"

    $script:WorkloadConfig = Read-WorkloadConfig
    Write-Log "Workload config: $script:WorkloadConfigPath"
    foreach ($wl in $WorkloadDefs.Keys) {
        $wlCfg  = $script:WorkloadConfig.$wl
        $wlCtrl = $script:WLControls[$wl]
        $p = if ($wlCfg) { [string]($wlCfg.Policy) }      else { "" }
        $s = if ($wlCfg) { [string]($wlCfg.Source) }      else { "" }
        $d = if ($wlCfg) { [string]($wlCfg.Destination) } else { "" }
        if ($p) { Write-Log "  $wl policy: $p" "OK" }      else { Write-Log "  $wl policy: (none - edit workloads.json)" "WARN" }
        if ($s) { $wlCtrl.Src.Text  = $s; Write-Log "  $wl source: $s" "OK" }      else { Write-Log "  $wl source: (none - edit workloads.json)" "WARN" }
        if ($d) { $wlCtrl.Dest.Text = $d; Write-Log "  $wl destination: $d" "OK" } else { Write-Log "  $wl destination: (none - edit workloads.json)" "WARN" }
    }

    $savedCfg = Get-FlyConfig
    if ($savedCfg) {
        $tbFlyUrl.Text  = $savedCfg.Url
        $tbFlyId.Text   = $savedCfg.ClientId
        $tbFlyPass.Text = $savedCfg.ClientSecret
        Write-Log "Credentials loaded from saved config." "OK"
        Write-Log "Auto-connecting..."
        try {
            if (-not (Get-Module -Name Fly.Client -ListAvailable)) {
                throw "Fly.Client module not found. Run: Install-Module Fly.Client -Scope CurrentUser"
            }
            Import-Module Fly.Client -ErrorAction Stop
            Connect-Fly -Url $savedCfg.Url -ClientId $savedCfg.ClientId -ClientSecret $savedCfg.ClientSecret -ErrorAction Stop
            $dotFly.ForeColor       = $clrGreen
            $btnRun.Enabled         = $true
            $lblRunStatus.Text      = "Ready"
            $lblRunStatus.ForeColor = $clrGreen
            Write-Log "Auto-connected to Fly OK" "OK"
        } catch {
            Write-Log "Auto-connect failed: $($_.Exception.Message)" "WARN"
            Write-Log "Click Connect to retry manually." "INFO"
        }
    }

    $sharedCfg = Read-SharedConfig
    if ($sharedCfg.TenantName -and [string]::IsNullOrWhiteSpace($tbPrefix.Text)) {
        $tbPrefix.Text = $sharedCfg.TenantName
        Write-Log "Customer Prefix pre-filled from shared config: $($sharedCfg.TenantName)" "OK"
    }
    if ($sharedCfg.SecretExpiry) {
        try {
            $expiry   = [datetime]$sharedCfg.SecretExpiry
            $daysLeft = ($expiry - (Get-Date)).Days
            if    ($daysLeft -le 0)  { Write-Log "Client secret EXPIRED ($($expiry.ToString('yyyy-MM-dd'))) — renew via Create App Registration." "ERROR" }
            elseif ($daysLeft -le 30) { Write-Log "Client secret expires in $daysLeft day(s) on $($expiry.ToString('yyyy-MM-dd')) — plan renewal soon." "WARN" }
        } catch { }
    }

    [System.Windows.Forms.Application]::Run($Form)
}

# ═════════════════════════════════════════════════════════════════════════════
# MIGRATION REPORTS
# ═════════════════════════════════════════════════════════════════════════════
function Show-ReportingForm {

    # ── Error pattern analysis ─────────────────────────────────────────────
    $errPatterns = @(
        [pscustomobject]@{
            Pattern = [regex]::new('access.?denied|permission.?denied|insufficient.?privil|forbidden|403', 'IgnoreCase')
            Type    = 'Access Denied'
            Fix     = 'Ensure the migration account has Site Collection Admin (SharePoint/OneDrive), Full Access (Exchange), or equivalent rights on source and destination. Re-test the connection after granting permissions.'
        }
        [pscustomobject]@{
            Pattern = [regex]::new('401|unauthorized|token.?expired|invalid.?credential|auth.*fail', 'IgnoreCase')
            Type    = 'Authentication Error'
            Fix     = 'Credentials have expired or are incorrect. Reconnect to the Fly API and re-test before retrying the migration.'
        }
        [pscustomobject]@{
            Pattern = [regex]::new('throttl|429|too.?many.?request|rate.?limit', 'IgnoreCase')
            Type    = 'Throttling'
            Fix     = 'Microsoft is rate-limiting requests. Fly will retry automatically. Consider reducing project concurrency in the Fly portal under Project Settings > Advanced.'
        }
        [pscustomobject]@{
            Pattern = [regex]::new('timeout|timed.?out|connection.?reset|socket|network', 'IgnoreCase')
            Type    = 'Network Timeout'
            Fix     = 'A network interruption occurred during transfer. The item will be retried on the next incremental pass. If persistent, check firewall rules or increase the Fly timeout setting.'
        }
        [pscustomobject]@{
            Pattern = [regex]::new('not.?found|does.?not.?exist|no.?such|404|mailbox.*missing|smtp.*invalid', 'IgnoreCase')
            Type    = 'Item / Mailbox Not Found'
            Fix     = 'The source or destination object no longer exists. Verify the URL, email address, or mailbox in the mapping CSV and ensure the destination is licensed and provisioned.'
        }
        [pscustomobject]@{
            Pattern = [regex]::new('size.?exceed|too.?large|exceeds.?limit|max.?size|file.?too.?big', 'IgnoreCase')
            Type    = 'Item Too Large'
            Fix     = 'The item exceeds the Microsoft size limit (e.g. 250 GB for SharePoint files, 150 MB for Exchange items). Split, compress, or migrate manually outside of Fly.'
        }
        [pscustomobject]@{
            Pattern = [regex]::new('duplicate|already.?exist|conflict', 'IgnoreCase')
            Type    = 'Duplicate / Conflict'
            Fix     = 'An item with the same name exists at the destination. Update the Fly project conflict resolution policy (Overwrite vs. Skip) under Project Settings > Migration Policy.'
        }
        [pscustomobject]@{
            Pattern = [regex]::new('unsupported|not.?support|cannot.?migrat', 'IgnoreCase')
            Type    = 'Unsupported Content'
            Fix     = 'This content type is not supported by Fly. Consult the AvePoint supported content matrix and migrate this item manually if required.'
        }
    )

    function Get-ErrorAnalysis([string]$Message) {
        if ([string]::IsNullOrWhiteSpace($Message)) {
            return [pscustomobject]@{ Type = '—'; Fix = '—' }
        }
        foreach ($p in $errPatterns) {
            if ($p.Pattern.IsMatch($Message)) {
                return [pscustomobject]@{ Type = $p.Type; Fix = $p.Fix }
            }
        }
        return [pscustomobject]@{
            Type = 'Unknown Error'
            Fix  = 'Review the full error message in the log. Check the Fly portal for more detail, or contact AvePoint support if the error persists.'
        }
    }

    function Find-RowField($Row, [string[]]$Candidates) {
        foreach ($c in $Candidates) {
            $prop = $Row.PSObject.Properties[$c]
            if ($prop -and -not [string]::IsNullOrWhiteSpace($prop.Value)) { return $prop.Value }
        }
        foreach ($c in $Candidates) {
            $prop = $Row.PSObject.Properties | Where-Object { $_.Name -ieq $c } | Select-Object -First 1
            if ($prop -and -not [string]::IsNullOrWhiteSpace($prop.Value)) { return $prop.Value }
        }
        return ''
    }

    # ── Report cmdlet map ──────────────────────────────────────────────────
    $rptCmdlets = [ordered]@{
        'SharePoint'  = @{ migration = 'Export-FlySharePointMigrationReport'; mapping = 'Export-FlySharePointMappingStatus'; Display = 'SharePoint Online'    }
        'Exchange'    = @{ migration = 'Export-FlyExchangeMigrationReport';   mapping = 'Export-FlyExchangeMappingStatus';   Display = 'Exchange Online'       }
        'OneDrive'    = @{ migration = 'Export-FlyOneDriveMigrationReport';   mapping = 'Export-FlyOneDriveMappingStatus';   Display = 'OneDrive for Business' }
        'Teams'       = @{ migration = 'Export-FlyTeamsMigrationReport';      mapping = 'Export-FlyTeamsMappingStatus';      Display = 'Microsoft Teams'       }
        'Teams Chat'  = @{ migration = 'Export-FlyTeamChatMigrationReport';   mapping = 'Export-FlyTeamChatMappingStatus';   Display = 'Teams Chat'            }
        'Groups'      = @{ migration = 'Export-FlyM365GroupMigrationReport';  mapping = 'Export-FlyM365GroupMappingStatus';  Display = 'Microsoft 365 Groups'  }
    }

    # ── Build Form ─────────────────────────────────────────────────────────
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text            = "AvePoint Fly - Migration Reports"
    $Form.WindowState     = [System.Windows.Forms.FormWindowState]::Maximized
    $Form.StartPosition   = [System.Windows.Forms.FormStartPosition]::WindowsDefaultBounds
    $Form.BackColor       = $clrBg
    $Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $Form.MinimumSize     = [System.Drawing.Size]::new(1024, 768)
    $Form.Font            = $FontBody

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Height = 46; $hdr.Dock = [System.Windows.Forms.DockStyle]::Top
    $hdr.BackColor = $clrAccent
    $Form.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 30
    $hdrTitle = New-Object System.Windows.Forms.Label
    $hdrTitle.Text      = "  Migration Reports"
    $hdrTitle.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
    $hdrTitle.ForeColor = [System.Drawing.Color]::White
    $hdrTitle.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrTitle.Size      = [System.Drawing.Size]::new(400, 46)
    $hdrTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdrTitle.Anchor    = $AnchorTL
    $hdr.Controls.Add($hdrTitle)

    $tlp = New-Object System.Windows.Forms.TableLayoutPanel
    $tlp.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $tlp.ColumnCount = 1
    $tlp.RowCount    = 5
    $tlp.Padding     = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
    $tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 132))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,  48))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,  40))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,  60))) | Out-Null
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,  40))) | Out-Null
    $Form.Controls.Add($tlp)

    # ── Row 0: Report Options ───────────────────────────────────────────────
    $c2 = New-CardPanel "REPORT OPTIONS"
    $tlp.Controls.Add($c2.Parent, 0, 0)

    New-Lbl $c2 "Customer Prefix" 16 28 | Out-Null
    $tbRPrefix = New-TB $c2 16 44 180

    New-Lbl $c2 "Report Type" 220 28 | Out-Null
    $rdoMigration = New-Object System.Windows.Forms.RadioButton
    $rdoMigration.Text = "Migration Report"; $rdoMigration.Font = $FontBody
    $rdoMigration.Location = [System.Drawing.Point]::new(220, 46); $rdoMigration.AutoSize = $true; $rdoMigration.Checked = $true
    $c2.Controls.Add($rdoMigration)
    $rdoMapping = New-Object System.Windows.Forms.RadioButton
    $rdoMapping.Text = "Mapping Status"; $rdoMapping.Font = $FontBody
    $rdoMapping.Location = [System.Drawing.Point]::new(370, 46); $rdoMapping.AutoSize = $true
    $c2.Controls.Add($rdoMapping)

    New-Lbl $c2 "Workloads" 16 78 | Out-Null
    $script:rptWLChecks = [ordered]@{}
    $rptWLLabels = [ordered]@{
        'SharePoint'  = 'SharePoint Online'
        'Exchange'    = 'Exchange Online'
        'OneDrive'    = 'OneDrive for Business'
        'Teams'       = 'Microsoft Teams'
        'Teams Chat'  = 'Teams Chat'
        'Groups'      = 'Microsoft 365 Groups'
    }
    $xi = 0
    foreach ($wl in $rptWLLabels.Keys) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = $rptWLLabels[$wl]; $chk.Font = $FontBody
        $chk.Location = [System.Drawing.Point]::new(16 + ($xi * 185), 95)
        $chk.AutoSize = $true; $chk.Checked = $true
        $c2.Controls.Add($chk)
        $script:rptWLChecks[$wl] = $chk
        $xi++
    }

    # ── Row 1: Action bar ──────────────────────────────────────────────────
    $c3 = New-CardPanel ""
    $tlp.Controls.Add($c3.Parent, 0, 1)

    $btnRRun    = New-Btn $c3 "Fetch Report" 16 10 140 28
    $btnRRun.Enabled = $false
    $btnRExport = New-Btn $c3 "Export CSV"  168 10 120 28 $false
    $btnRExport.Enabled = $false
    $btnRClear  = New-Btn $c3 "Clear"       300 10  80 28 $false
    $btnRCreds  = New-Btn $c3 "Credentials..." 392 10 110 28 $false
    $dotRConn   = New-Dot $c3 512 16

    $lblRStatus = New-Object System.Windows.Forms.Label
    $lblRStatus.Location  = [System.Drawing.Point]::new(530, 16)
    $lblRStatus.AutoSize  = $false; $lblRStatus.Font = $FontBody
    $lblRStatus.ForeColor = $clrMuted; $lblRStatus.Text = "Connecting..."
    $lblRStatus.Anchor    = $AnchorTLR
    $c3.Controls.Add($lblRStatus)

    $btnRClose = New-Btn $c3 "Close" 0 10 100 28 $false $true
    $btnRClose.Add_Click({ $Form.Close() })

    $c3.Add_SizeChanged({
        $btnRClose.Left   = $c3.Width - 108
        $lblRStatus.Width = $btnRClose.Left - 538 - 8
    })

    # ── Row 2: Summary bar ─────────────────────────────────────────────────
    $c4 = New-CardPanel ""
    $tlp.Controls.Add($c4.Parent, 0, 2)

    $summaryFont = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
    $lblRTotal   = New-Object System.Windows.Forms.Label
    $lblRSuccess = New-Object System.Windows.Forms.Label
    $lblRWarn    = New-Object System.Windows.Forms.Label
    $lblRFailed  = New-Object System.Windows.Forms.Label
    foreach ($lbl in @($lblRTotal, $lblRSuccess, $lblRWarn, $lblRFailed)) {
        $lbl.Font = $summaryFont; $lbl.AutoSize = $true; $lbl.ForeColor = $clrMuted
    }
    $lblRTotal.Location   = [System.Drawing.Point]::new(16,  10)
    $lblRSuccess.Location = [System.Drawing.Point]::new(160, 10)
    $lblRWarn.Location    = [System.Drawing.Point]::new(320, 10)
    $lblRFailed.Location  = [System.Drawing.Point]::new(480, 10)
    $lblRTotal.Text = "Total: 0"; $lblRSuccess.Text = "Succeeded: 0"
    $lblRWarn.Text  = "Warnings: 0"; $lblRFailed.Text  = "Failed: 0"
    $c4.Controls.AddRange(@($lblRTotal, $lblRSuccess, $lblRWarn, $lblRFailed))

    $script:rptStats = @{ Total = 0; Success = 0; Warn = 0; Failed = 0 }

    function Update-RptStats {
        $lblRTotal.Text        = "Total: $($script:rptStats.Total)";     $lblRTotal.ForeColor   = $clrText
        $lblRSuccess.Text      = "Succeeded: $($script:rptStats.Success)"
        $lblRSuccess.ForeColor = if ($script:rptStats.Success -gt 0) { $clrGreen } else { $clrMuted }
        $lblRWarn.Text         = "Warnings: $($script:rptStats.Warn)"
        $lblRWarn.ForeColor    = if ($script:rptStats.Warn -gt 0) { $clrAmber } else { $clrMuted }
        $lblRFailed.Text       = "Failed: $($script:rptStats.Failed)"
        $lblRFailed.ForeColor  = if ($script:rptStats.Failed -gt 0) { $clrRed } else { $clrMuted }
        [System.Windows.Forms.Application]::DoEvents()
    }

    # ── Row 3: Error Analysis DataGridView ─────────────────────────────────
    $c5 = New-CardPanel "ERROR ANALYSIS"
    $c5.Padding = New-Object System.Windows.Forms.Padding(0, 26, 0, 0)
    $tlp.Controls.Add($c5.Parent, 0, 3)

    $dgv = New-Object System.Windows.Forms.DataGridView
    $dgv.Dock                      = [System.Windows.Forms.DockStyle]::Fill
    $dgv.Margin                    = New-Object System.Windows.Forms.Padding(16, 26, 8, 8)
    $dgv.AutoGenerateColumns       = $false
    $dgv.ReadOnly                  = $true
    $dgv.AllowUserToAddRows        = $false
    $dgv.AllowUserToDeleteRows     = $false
    $dgv.BackgroundColor           = [System.Drawing.Color]::White
    $dgv.BorderStyle               = [System.Windows.Forms.BorderStyle]::None
    $dgv.ColumnHeadersBorderStyle  = [System.Windows.Forms.DataGridViewHeaderBorderStyle]::Single
    $dgv.ColumnHeadersDefaultCellStyle.BackColor = $clrBg
    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = $clrMuted
    $dgv.ColumnHeadersDefaultCellStyle.Font      = $FontCap
    $dgv.CellBorderStyle           = [System.Windows.Forms.DataGridViewCellBorderStyle]::SingleHorizontal
    $dgv.GridColor                 = $clrBorder
    $dgv.RowHeadersVisible         = $false
    $dgv.SelectionMode             = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $dgv.Font                      = New-Object System.Drawing.Font("Segoe UI", 9)
    $dgv.AutoSizeRowsMode          = [System.Windows.Forms.DataGridViewAutoSizeRowsMode]::AllCells
    $dgv.DefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True
    $dgv.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 252)

    foreach ($cd in @(
        @{ Name='ColWorkload'; Header='Workload';        Width=140; Fill=$false }
        @{ Name='ColSource';   Header='Source Object';   Width=200; Fill=$false }
        @{ Name='ColStatus';   Header='Status';          Width=100; Fill=$false }
        @{ Name='ColErrType';  Header='Error Type';      Width=160; Fill=$false }
        @{ Name='ColErrMsg';   Header='Error Message';   Width=220; Fill=$false }
        @{ Name='ColFix';      Header='Recommended Fix'; Width=0;   Fill=$true  }
    )) {
        $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.Name = $cd.Name; $col.HeaderText = $cd.Header
        $col.DefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True
        if ($cd.Fill) { $col.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill }
        else          { $col.Width = $cd.Width }
        $dgv.Columns.Add($col) | Out-Null
    }

    $dgv.Add_CellFormatting({
        param($s, $e)
        if ($e.RowIndex -lt 0 -or $e.ColumnIndex -ne 2) { return }
        $val = $dgv.Rows[$e.RowIndex].Cells['ColStatus'].Value
        if (-not $val) { return }
        switch -Regex ($val) {
            '^[Ff]ail|^[Ee]rror' { $e.CellStyle.ForeColor = $clrRed;   $e.CellStyle.Font = $FontBold; $e.FormattingApplied = $true }
            '^[Ww]arn|^[Ss]kip'  { $e.CellStyle.ForeColor = $clrAmber; $e.CellStyle.Font = $FontBold; $e.FormattingApplied = $true }
        }
    })
    $c5.Controls.Add($dgv)

    # ── Row 4: Log ─────────────────────────────────────────────────────────
    $c6 = New-CardPanel "LOG"
    $c6.Padding = New-Object System.Windows.Forms.Padding(0, 26, 0, 0)
    $tlp.Controls.Add($c6.Parent, 0, 4)

    $rptLog = New-Object System.Windows.Forms.RichTextBox
    $rptLog.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $rptLog.Font        = $FontMono; $rptLog.BackColor = $clrLogBg
    $rptLog.ForeColor   = [System.Drawing.Color]::FromArgb(190, 210, 255)
    $rptLog.ReadOnly    = $true; $rptLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $rptLog.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $rptLog.Margin      = New-Object System.Windows.Forms.Padding(16, 26, 8, 8)
    $c6.Controls.Add($rptLog)

    function Write-Log {
        param([string]$Msg, [string]$Level = "INFO")
        $ts = Get-Date -Format "HH:mm:ss"
        $rptLog.SelectionStart = $rptLog.TextLength; $rptLog.SelectionLength = 0
        $rptLog.SelectionColor = [System.Drawing.Color]::FromArgb(80, 95, 120)
        $rptLog.AppendText("$ts ")
        $rptLog.SelectionColor = switch ($Level) {
            "OK"    { [System.Drawing.Color]::FromArgb(65,  195, 110) }
            "WARN"  { [System.Drawing.Color]::FromArgb(220, 165, 45)  }
            "ERROR" { [System.Drawing.Color]::FromArgb(225, 80,  80)  }
            default { [System.Drawing.Color]::FromArgb(120, 155, 220) }
        }
        $rptLog.AppendText("[$Level] ")
        $rptLog.SelectionColor = [System.Drawing.Color]::FromArgb(205, 212, 230)
        $rptLog.AppendText("$Msg`n")
        $rptLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    $script:rptExportRows = [System.Collections.Generic.List[object]]::new()

    # ── Config helpers ─────────────────────────────────────────────────────
    $rptCfgPath = Join-Path $env:APPDATA "FlyMigration\config.json"

    function Read-RptConfig {
        if (-not (Test-Path $rptCfgPath)) { return $null }
        try {
            $cfg    = Get-Content $rptCfgPath -Raw | ConvertFrom-Json
            $secure = $cfg.EncSecret | ConvertTo-SecureString
            $bstr   = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            $plain  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            return @{ Url = $cfg.Url; ClientId = $cfg.ClientId; ClientSecret = $plain }
        } catch { return $null }
    }

    function Save-RptConfig([string]$Url, [string]$ClientId, [string]$ClientSecret) {
        $dir = Split-Path $rptCfgPath
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $enc = $ClientSecret | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString
        @{ Url = $Url; ClientId = $ClientId; EncSecret = $enc } |
            ConvertTo-Json | Set-Content -Path $rptCfgPath -Encoding UTF8
    }

    function Connect-RptFly([hashtable]$Cfg) {
        $dotRConn.ForeColor   = $clrGrey
        $lblRStatus.Text      = "Connecting..."; $lblRStatus.ForeColor = $clrMuted
        [System.Windows.Forms.Application]::DoEvents()
        try {
            if (-not (Get-Module -Name Fly.Client -ListAvailable)) {
                throw "Fly.Client module not found. Run: Install-Module Fly.Client -Scope CurrentUser"
            }
            Import-Module Fly.Client -ErrorAction Stop
            Connect-Fly -Url $Cfg.Url -ClientId $Cfg.ClientId -ClientSecret $Cfg.ClientSecret -ErrorAction Stop
            Write-Log "Connected to Fly API." "OK"
            $dotRConn.ForeColor   = $clrGreen
            $btnRRun.Enabled      = $true
            $lblRStatus.Text      = "Ready"; $lblRStatus.ForeColor = $clrGreen
        } catch {
            $dotRConn.ForeColor   = $clrRed
            $btnRRun.Enabled      = $false
            $lblRStatus.Text      = "Not connected"; $lblRStatus.ForeColor = $clrRed
            Write-Log "Connection failed: $($_.Exception.Message)" "ERROR"
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    # ── Credentials dialog ─────────────────────────────────────────────────
    $btnRCreds.Add_Click({
        $existing = Read-RptConfig
        $cdlg = New-Object System.Windows.Forms.Form
        $cdlg.Text            = "Fly API Credentials"
        $cdlg.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterParent
        $cdlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $cdlg.MaximizeBox     = $false; $cdlg.MinimizeBox = $false
        $cdlg.BackColor       = $clrBg; $cdlg.Font = $FontBody
        $cdlg.ClientSize      = [System.Drawing.Size]::new(520, 220)

        $mkLbl = { param($t,$x,$y)
            $l = New-Object System.Windows.Forms.Label
            $l.Text = $t; $l.Location = [System.Drawing.Point]::new($x,$y)
            $l.AutoSize = $true; $l.ForeColor = $clrMuted; $l.Font = $FontCap
            $cdlg.Controls.Add($l)
        }
        $mkTb = { param($x,$y,$w,[bool]$pwd=$false)
            $tb = New-Object System.Windows.Forms.TextBox
            $tb.Location = [System.Drawing.Point]::new($x,$y)
            $tb.Size     = [System.Drawing.Size]::new($w,26)
            $tb.BackColor = [System.Drawing.Color]::White
            $tb.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
            if ($pwd) { $tb.UseSystemPasswordChar = $true }
            $cdlg.Controls.Add($tb); $tb
        }

        & $mkLbl "FLY API URL"   16 16
        $cdTbUrl = & $mkTb 16 32 488
        & $mkLbl "AOS CLIENT ID" 16 72
        $cdTbCid = & $mkTb 16 88 230
        & $mkLbl "CLIENT SECRET" 260 72
        $cdTbSec = & $mkTb 260 88 244 $true

        if ($existing) {
            $cdTbUrl.Text = $existing.Url
            $cdTbCid.Text = $existing.ClientId
            $cdTbSec.Text = $existing.ClientSecret
        }

        $btnSave = New-Object System.Windows.Forms.Button
        $btnSave.Text = "Save & Connect"; $btnSave.Size = [System.Drawing.Size]::new(130,30)
        $btnSave.Location  = [System.Drawing.Point]::new(16,168)
        $btnSave.BackColor = $clrAccent; $btnSave.ForeColor = [System.Drawing.Color]::White
        $btnSave.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $cdlg.Controls.Add($btnSave)

        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text = "Cancel"; $btnCancel.Size = [System.Drawing.Size]::new(80,30)
        $btnCancel.Location  = [System.Drawing.Point]::new(154,168)
        $btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnCancel.BackColor = $clrPanel; $btnCancel.ForeColor = $clrText
        $cdlg.Controls.Add($btnCancel)

        $btnSave.Add_Click({
            $url = $cdTbUrl.Text.Trim(); $cid = $cdTbCid.Text.Trim(); $sec = $cdTbSec.Text.Trim()
            if (-not $cid -or -not $sec) {
                [System.Windows.Forms.MessageBox]::Show("Client ID and Secret are required.", "Validation") | Out-Null
                return
            }
            Save-RptConfig -Url $url -ClientId $cid -ClientSecret $sec
            $cdlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $cdlg.Close()
        }.GetNewClosure())

        $btnCancel.Add_Click({ $cdlg.Close() })
        $cdlg.CancelButton = $btnCancel

        if ($cdlg.ShowDialog($Form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $cfg = Read-RptConfig
            if ($cfg) { Connect-RptFly -Cfg $cfg }
        }
    })

    # ── Reports cache directory ────────────────────────────────────────────────
    $script:rptDir = Join-Path $PSScriptRoot 'reports'
    if (-not (Test-Path $script:rptDir)) { New-Item -ItemType Directory -Path $script:rptDir -Force | Out-Null }

    function Get-CachedReport {
        param([string]$Prefix, [string]$Workload, [string]$ReportType)
        $cutoff = (Get-Date).AddDays(-2)
        $safe   = [regex]::Escape(($Workload -replace '\s', ''))
        Get-ChildItem $script:rptDir -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -imatch [regex]::Escape($Prefix) -and $_.Name -imatch $safe -and $_.Name -imatch $ReportType } |
            Where-Object { $_.LastWriteTime -ge $cutoff } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    function Show-ReportSourceDialog {
        param([string[]]$Workloads, [string]$Prefix, [string]$ReportType, [hashtable]$CachedFiles)
        $Workloads = @($Workloads)

        $choices = [ordered]@{}
        foreach ($wl in $Workloads) {
            $choices[$wl] = [pscustomobject]@{
                Mode = if ($CachedFiles[$wl]) { 'cached' } else { 'fresh' }
                File = if ($CachedFiles[$wl]) { $CachedFiles[$wl].FullName } else { $null }
            }
        }

        $rowH   = 56
        $bodyH  = $Workloads.Count * $rowH + 32
        $dlgH   = 44 + 40 + $bodyH + 50   # header + quick-bar + body + footer

        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text            = "Select Report Sources"
        $dlg.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $dlg.MaximizeBox     = $false
        $dlg.MinimizeBox     = $false
        $dlg.BackColor       = $clrBg
        $dlg.Font            = $FontBody
        $dlg.ClientSize      = [System.Drawing.Size]::new(740, $dlgH)

        # Header bar
        $hdr = New-Object System.Windows.Forms.Panel
        $hdr.Size = [System.Drawing.Size]::new(740, 44); $hdr.BackColor = $clrAccent
        $dlg.Controls.Add($hdr)
        $hdrLbl = New-Object System.Windows.Forms.Label
        $hdrLbl.Text      = "  Select Report Sources  —  $Prefix  ($ReportType)"
        $hdrLbl.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
        $hdrLbl.ForeColor = [System.Drawing.Color]::White
        $hdrLbl.Location  = [System.Drawing.Point]::new(8, 13)
        $hdrLbl.AutoSize  = $true
        $hdr.Controls.Add($hdrLbl)

        # Quick-select buttons
        $btnAllCached = New-Btn $dlg "Use All Cached"     10 52 136 28 $false
        $btnAllFresh  = New-Btn $dlg "Generate All Fresh" 154 52 150 28 $false
        $btnAllCached.Enabled = [bool]($CachedFiles.Values | Where-Object { $_ })

        # Column header labels
        $colX = @(10, 164, 390, 580)
        foreach ($i in 0..3) {
            $lh = New-Object System.Windows.Forms.Label
            $lh.Text      = @('Workload', 'Cached report  (< 2 days old)', 'Source', 'Browse')[($i)]
            $lh.Font      = $FontCap; $lh.ForeColor = $clrMuted
            $lh.Location  = [System.Drawing.Point]::new($colX[$i], 90)
            $lh.AutoSize  = $true
            $dlg.Controls.Add($lh)
        }

        $rdoGroups = [ordered]@{}
        $y = 106

        foreach ($wl in $Workloads) {
            $cached = $CachedFiles[$wl]

            # Workload label
            $wlLbl = New-Object System.Windows.Forms.Label
            $wlLbl.Text = $wl; $wlLbl.Font = $FontBold; $wlLbl.ForeColor = $clrText
            $wlLbl.Location = [System.Drawing.Point]::new($colX[0], $y + 8); $wlLbl.AutoSize = $true
            $dlg.Controls.Add($wlLbl)

            # Cached file info
            $cacheLbl = New-Object System.Windows.Forms.Label
            $cacheLbl.Location = [System.Drawing.Point]::new($colX[1], $y)
            $cacheLbl.Size     = [System.Drawing.Size]::new(218, 48)
            $cacheLbl.Font     = $FontBody
            if ($cached) {
                $hrs    = ((Get-Date) - $cached.LastWriteTime).TotalHours
                $ageStr = if ($hrs -lt 1) { "$([int]($hrs*60))m ago" } `
                          elseif ($hrs -lt 24) { "$([Math]::Round($hrs,1))h ago" } `
                          else { "$([Math]::Round($hrs/24,1))d ago" }
                $cacheLbl.Text      = $cached.Name + "`n" + $ageStr
                $cacheLbl.ForeColor = $clrGreen
            } else {
                $cacheLbl.Text      = "None found"
                $cacheLbl.ForeColor = $clrMuted
            }
            $dlg.Controls.Add($cacheLbl)

            # Radio panel (groups the three radios so they auto-mutually-exclude per workload)
            $rdoPnl = New-Object System.Windows.Forms.Panel
            $rdoPnl.Location  = [System.Drawing.Point]::new($colX[2], $y)
            $rdoPnl.Size      = [System.Drawing.Size]::new(178, 52)
            $rdoPnl.BackColor = $clrBg
            $dlg.Controls.Add($rdoPnl)

            $rdoCached = New-Object System.Windows.Forms.RadioButton
            $rdoCached.Text = "Use cached"; $rdoCached.Font = $FontBody
            $rdoCached.Location = [System.Drawing.Point]::new(0, 2); $rdoCached.AutoSize = $true
            $rdoCached.Enabled  = [bool]$cached; $rdoCached.Checked = [bool]$cached
            $rdoPnl.Controls.Add($rdoCached)

            $rdoFresh = New-Object System.Windows.Forms.RadioButton
            $rdoFresh.Text = "Generate fresh"; $rdoFresh.Font = $FontBody
            $rdoFresh.Location = [System.Drawing.Point]::new(0, 26); $rdoFresh.AutoSize = $true
            $rdoFresh.Checked  = -not $cached
            $rdoPnl.Controls.Add($rdoFresh)

            # Browse radio + label live outside the panel (col 3)
            $rdoBrowse = New-Object System.Windows.Forms.Panel
            $rdoBrowse_rdo = New-Object System.Windows.Forms.RadioButton
            $rdoBrowse_rdo.Text = "Browse for file..."; $rdoBrowse_rdo.Font = $FontBody
            $rdoBrowse_rdo.Location = [System.Drawing.Point]::new(0, 0); $rdoBrowse_rdo.AutoSize = $true
            $rdoPnl.Controls.Add($rdoBrowse_rdo)
            $rdoBrowse_rdo.Location = [System.Drawing.Point]::new($colX[3] - $colX[2], 2)

            $brwLbl = New-Object System.Windows.Forms.Label
            $brwLbl.Text      = "(no file chosen)"
            $brwLbl.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5)
            $brwLbl.ForeColor = $clrMuted
            $brwLbl.Location  = [System.Drawing.Point]::new($colX[3] - $colX[2], 26)
            $brwLbl.Size      = [System.Drawing.Size]::new(148, 18)
            $rdoPnl.Controls.Add($brwLbl)

            # Separator
            $sep = New-Object System.Windows.Forms.Label
            $sep.Location  = [System.Drawing.Point]::new(10, $y + $rowH - 2)
            $sep.Size      = [System.Drawing.Size]::new(720, 1)
            $sep.BackColor = $clrBorder
            $dlg.Controls.Add($sep)

            $rdoGroups[$wl] = @{ Cached = $rdoCached; Fresh = $rdoFresh; Browse = $rdoBrowse_rdo }

            # Wire events with closures
            $captWl     = $wl
            $captCached = $cached
            $captRdoC   = $rdoCached
            $captRdoF   = $rdoFresh
            $captRdoB   = $rdoBrowse_rdo
            $captBrwLbl = $brwLbl

            $rdoCached.Add_CheckedChanged({
                if ($captRdoC.Checked) { $choices[$captWl].Mode = 'cached'; $choices[$captWl].File = $captCached.FullName }
            }.GetNewClosure())

            $rdoFresh.Add_CheckedChanged({
                if ($captRdoF.Checked) { $choices[$captWl].Mode = 'fresh'; $choices[$captWl].File = $null }
            }.GetNewClosure())

            $rdoBrowse_rdo.Add_CheckedChanged({
                if (-not $captRdoB.Checked) { return }
                $ofd = New-Object System.Windows.Forms.OpenFileDialog
                $ofd.Filter = "CSV / report files (*.csv)|*.csv|All files (*.*)|*.*"
                $ofd.Title  = "Select report file for $captWl"
                if ($ofd.ShowDialog() -eq 'OK') {
                    $choices[$captWl].Mode = 'browse'
                    $choices[$captWl].File = $ofd.FileName
                    $captBrwLbl.Text       = [System.IO.Path]::GetFileName($ofd.FileName)
                    $captBrwLbl.ForeColor  = $clrText
                } else {
                    if ($captCached) { $captRdoC.Checked = $true } else { $captRdoF.Checked = $true }
                }
            }.GetNewClosure())

            $y += $rowH
        }

        # Quick-select handlers
        $btnAllCached.Add_Click({
            foreach ($wl in $Workloads) { if ($rdoGroups[$wl].Cached.Enabled) { $rdoGroups[$wl].Cached.Checked = $true } }
        }.GetNewClosure())
        $btnAllFresh.Add_Click({
            foreach ($wl in $Workloads) { $rdoGroups[$wl].Fresh.Checked = $true }
        }.GetNewClosure())

        # Footer
        $btnOk     = New-Btn $dlg "Proceed" 474 ($dlg.ClientSize.Height - 42) 124 30
        $btnCancel = New-Btn $dlg "Cancel"  606 ($dlg.ClientSize.Height - 42) 124 30 $false
        $btnOk.Add_Click({     $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK;     $dlg.Close() })
        $btnCancel.Add_Click({ $dlg.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dlg.Close() })
        $dlg.AcceptButton = $btnOk; $dlg.CancelButton = $btnCancel

        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $choices }
        return $null
    }

    # ── Fetch Report ───────────────────────────────────────────────────────
    $btnRRun.Add_Click({
        $prefix     = $tbRPrefix.Text.Trim()
        $reportType = if ($rdoMigration.Checked) { 'migration' } else { 'mapping' }

        if ([string]::IsNullOrWhiteSpace($prefix)) { Write-Log "Customer Prefix is required." "ERROR"; return }

        $selected = [string[]]($script:rptWLChecks.Keys | Where-Object { $script:rptWLChecks[$_].Checked })
        if (-not $selected) { Write-Log "Select at least one workload." "ERROR"; return }

        # Scan reports folder for cached files < 2 days old
        $cachedFiles = [ordered]@{}
        foreach ($wl in $selected) { $cachedFiles[$wl] = Get-CachedReport -Prefix $prefix -Workload $wl -ReportType $reportType }

        # Show source selection dialog — always shown so Browse is always accessible
        $choices = Show-ReportSourceDialog -Workloads $selected -Prefix $prefix -ReportType $reportType -CachedFiles $cachedFiles
        if (-not $choices) { return }   # cancelled

        $btnRRun.Enabled = $false; $btnRExport.Enabled = $false
        $dgv.Rows.Clear(); $script:rptExportRows.Clear()
        $script:rptStats = @{ Total = 0; Success = 0; Warn = 0; Failed = 0 }
        Update-RptStats
        $lblRStatus.Text = "Loading reports..."; $lblRStatus.ForeColor = $clrMuted

        foreach ($wl in $selected) {
            $cmds     = $rptCmdlets[$wl]
            $cmdName  = $cmds[$reportType]
            $display  = $cmds['Display']
            $projName = "$prefix - $wl"
            $choice   = $choices[$wl]

            if (-not $cmdName -and $choice.Mode -eq 'fresh') {
                Write-Log "[$wl] No $reportType cmdlet defined — skipped." "WARN"; continue
            }

            $tempCsv = $null
            $tempDir = $null

            try {
                switch ($choice.Mode) {
                    'cached' {
                        $tempCsv = $choice.File
                        Write-Log "[$wl] Using cached report: $(Split-Path $tempCsv -Leaf)" "OK"
                    }
                    'browse' {
                        $tempCsv = $choice.File
                        Write-Log "[$wl] Using selected file: $(Split-Path $tempCsv -Leaf)" "OK"
                    }
                    'fresh' {
                        Write-Log "[$wl] Generating $reportType report for '$projName'..."
                        if ($reportType -eq 'migration') {
                            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
                            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                            & $cmdName -Project $projName -OutFolder $tempDir -ErrorAction Stop | Out-Null
                            $dl = Get-ChildItem $tempDir -Recurse -ErrorAction SilentlyContinue |
                                  Where-Object { -not $_.PSIsContainer } | Select-Object -First 1
                            if ($dl) {
                                $saveName = "$($projName -replace '[^\w ]') $reportType $(Get-Date -Format 'yyyyMMdd-HHmm').csv"
                                $savePath = Join-Path $script:rptDir $saveName
                                Copy-Item $dl.FullName $savePath -Force -ErrorAction SilentlyContinue
                                $tempCsv = $savePath
                                Write-Log "[$wl] Saved to cache: $saveName" "OK"
                            }
                        } else {
                            $tempCsv = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.csv'
                            & $cmdName -Project $projName -OutFile $tempCsv -ErrorAction Stop | Out-Null
                            if (Test-Path $tempCsv) {
                                $saveName = "$($projName -replace '[^\w ]') $reportType $(Get-Date -Format 'yyyyMMdd-HHmm').csv"
                                $savePath = Join-Path $script:rptDir $saveName
                                Copy-Item $tempCsv $savePath -Force -ErrorAction SilentlyContinue
                                Write-Log "[$wl] Saved to cache: $saveName" "OK"
                            }
                        }
                    }
                }

                if (-not $tempCsv -or -not (Test-Path $tempCsv)) {
                    Write-Log "[$wl] No report file available — Fly API returned no download URL. The report may be downloaded manually from the Fly portal download centre." "WARN"; continue
                }

                $rows = @(Import-Csv -Path $tempCsv -ErrorAction Stop)
                Write-Log "[$wl] $($rows.Count) rows retrieved." "OK"

                foreach ($row in $rows) {
                    $status = Find-RowField $row @('Status','Result','MigrationStatus','State')
                    $source = Find-RowField $row @('SourceItem','SourceUser','SourceSite','SourceMailbox','Source','Name','Item')
                    $errMsg = Find-RowField $row @('ErrorMessage','Error','Message','FailReason','Description','Details')

                    $script:rptStats.Total++
                    $isSuccess = $status -imatch '^success$|^completed$|^done$'
                    $isWarn    = $status -imatch '^warning|^skipped|^partial'
                    $isFail    = $status -imatch '^fail|^error'

                    if     ($isSuccess) { $script:rptStats.Success++ }
                    elseif ($isWarn)    { $script:rptStats.Warn++    }
                    elseif ($isFail)    { $script:rptStats.Failed++  }
                    elseif ($errMsg)    { $script:rptStats.Failed++  }
                    else                { $script:rptStats.Success++ }

                    if ($isSuccess -and -not $errMsg) { Update-RptStats; continue }
                    if (-not $errMsg -and -not $isFail -and -not $isWarn) { Update-RptStats; continue }

                    $analysis   = Get-ErrorAnalysis $errMsg
                    $srcDisplay = if ($source) { $source } else { '—' }
                    $stDisplay  = if ($status) { $status } else { '—' }
                    $errDisplay = if ($errMsg) { $errMsg } else { '—' }

                    $dgv.Rows.Add($display, $srcDisplay, $stDisplay, $analysis.Type, $errDisplay, $analysis.Fix) | Out-Null
                    $script:rptExportRows.Add([pscustomobject]@{
                        Workload       = $display
                        SourceObject   = $srcDisplay
                        Status         = $stDisplay
                        ErrorType      = $analysis.Type
                        ErrorMessage   = $errDisplay
                        RecommendedFix = $analysis.Fix
                    }) | Out-Null

                    Update-RptStats
                    [System.Windows.Forms.Application]::DoEvents()
                }
                Update-RptStats
            } catch {
                Write-Log "[$wl] Error: $($_.Exception.Message)" "ERROR"
            } finally {
                if ($tempDir -and (Test-Path $tempDir)) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }

        $failTxt = if ($script:rptStats.Failed -gt 0) { "$($script:rptStats.Failed) failed" } else { "no failures" }
        $lblRStatus.Text      = "Done. $($script:rptStats.Total) total — $failTxt."
        $lblRStatus.ForeColor = if ($script:rptStats.Failed -gt 0) { $clrRed } else { $clrGreen }
        $btnRRun.Enabled      = $true
        if ($script:rptExportRows.Count -gt 0) { $btnRExport.Enabled = $true }
        Write-Log "Complete: $($script:rptStats.Total) rows, $($script:rptStats.Failed) failed, $($script:rptStats.Warn) warnings." "OK"
    })

    # ── Export CSV ─────────────────────────────────────────────────────────
    $btnRExport.Add_Click({
        if ($script:rptExportRows.Count -eq 0) { Write-Log "No error rows to export." "WARN"; return }
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter   = "CSV files (*.csv)|*.csv"
        $dlg.FileName = "fly-report-errors-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        if ($dlg.ShowDialog() -eq 'OK') {
            $escape  = { param($v) '"' + ([string]$v -replace '"', '""') + '"' }
            $headers = @('Workload','Source Object','Status','Error Type','Error Message','Recommended Fix')
            $lines   = [System.Collections.Generic.List[string]]::new()
            $lines.Add(($headers | ForEach-Object { & $escape $_ }) -join ',')
            foreach ($r in $script:rptExportRows) {
                $lines.Add((@($r.Workload, $r.SourceObject, $r.Status, $r.ErrorType, $r.ErrorMessage, $r.RecommendedFix) |
                    ForEach-Object { & $escape $_ }) -join ',')
            }
            $lines | Set-Content -Path $dlg.FileName -Encoding UTF8
            Write-Log "Exported: $($dlg.FileName)" "OK"
        }
    })

    # ── Clear ──────────────────────────────────────────────────────────────
    $btnRClear.Add_Click({
        $dgv.Rows.Clear(); $script:rptExportRows.Clear()
        $script:rptStats = @{ Total = 0; Success = 0; Warn = 0; Failed = 0 }
        Update-RptStats; $rptLog.Clear(); $btnRExport.Enabled = $false
        $lblRStatus.Text      = if ($btnRRun.Enabled) { "Ready" } else { "Not connected" }
        $lblRStatus.ForeColor = $clrMuted
    })

    $sharedCfg = Read-SharedConfig
    if ($sharedCfg.TenantName -and [string]::IsNullOrWhiteSpace($tbRPrefix.Text)) {
        $tbRPrefix.Text = $sharedCfg.TenantName
    }

    # Auto-connect on load using saved config
    $Form.Add_Shown({
        $initCfg = Read-RptConfig
        if ($initCfg) {
            Connect-RptFly -Cfg $initCfg
        } else {
            $dotRConn.ForeColor   = $clrAmber
            $lblRStatus.Text      = "No credentials — click Credentials..."
            $lblRStatus.ForeColor = $clrAmber
            Write-Log "No saved credentials found. Click 'Credentials...' to set up Fly API access." "WARN"
        }
    })

    [System.Windows.Forms.Application]::Run($Form)
}

# ═════════════════════════════════════════════════════════════════════════════
# AOS TENANT & APP SETUP
# ═════════════════════════════════════════════════════════════════════════════
function Show-AosSetupForm {

    $script:aosSetupConnectorJs = Join-Path $PSScriptRoot 'fly-connector.js'

    [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
    [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationCore')

    [xml]$setupXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AOS Tenant &amp; App Setup"
        Width="820" Height="640" MinWidth="640" MinHeight="500"
        WindowStartupLocation="CenterScreen"
        Background="#F0F2F8">
    <DockPanel>
        <Border DockPanel.Dock="Top" Height="54" Background="#0064B4">
            <DockPanel Margin="10,0,16,0" VerticalAlignment="Center">
                <Image Name="ImgLogo" DockPanel.Dock="Left" Height="34" Width="34" Margin="0,0,8,0"
                       RenderOptions.BitmapScalingMode="HighQuality"/>
                <TextBlock FontFamily="Segoe UI" FontSize="15" Foreground="White" VerticalAlignment="Center">
                    <Run Text="AOS Tenant &amp; App Setup" FontWeight="Light"/>
                </TextBlock>
            </DockPanel>
        </Border>

        <Grid Margin="16,10,16,14">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Sign-in -->
            <GroupBox Grid.Row="0" Header="AOS Sign-in  (one-time, session persisted)" Margin="0,0,0,6">
                <StackPanel Orientation="Horizontal">
                    <Button Name="BtnSignIn" Content="Sign in to AOS..." Width="160"
                            Background="#0064B4" Foreground="White" FontWeight="SemiBold" Margin="4,4,8,4"/>
                    <TextBlock Name="TxtAuthStatus" VerticalAlignment="Center" Foreground="#555"
                               Text="Click to sign in — opens Chrome, complete Microsoft SSO, then close it."/>
                </StackPanel>
            </GroupBox>

            <!-- Tenant details -->
            <GroupBox Grid.Row="1" Header="Tenant" Margin="0,0,0,6">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="150"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="20"/>
                        <ColumnDefinition Width="150"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Label  Grid.Column="0" Content="Display Name:" VerticalAlignment="Center"/>
                    <TextBox Grid.Column="1" Name="TxtDisplayName" Margin="0,4,0,4"
                             ToolTip="Shown in AOS, e.g. OurVolaris"/>
                    <Label  Grid.Column="3" Content="Search Code:" VerticalAlignment="Center"/>
                    <TextBox Grid.Column="4" Name="TxtSearchCode" Margin="0,4,0,4"
                             ToolTip="Short code used in the AOS Tenant dropdown, e.g. ourvolaris"/>
                </Grid>
            </GroupBox>

            <!-- App profile -->
            <GroupBox Grid.Row="2" Header="App Profile (credentials registered in AOS)" Margin="0,0,0,6">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="150"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="20"/>
                        <ColumnDefinition Width="150"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition/>
                        <RowDefinition/>
                    </Grid.RowDefinitions>
                    <Label  Grid.Row="0" Grid.Column="0" Content="Profile Name:" VerticalAlignment="Center"/>
                    <TextBox Grid.Row="0" Grid.Column="1" Name="TxtAppProfileName" Margin="0,4,0,2"
                             ToolTip="Name for the app profile in AOS App Management, e.g. OurVolaris App"/>
                    <Label  Grid.Row="0" Grid.Column="3" Content="Client ID:" VerticalAlignment="Center"/>
                    <TextBox Grid.Row="0" Grid.Column="4" Name="TxtClientId" Margin="0,4,0,2"
                             ToolTip="App (Client) ID from Entra / the Create App Registration screen"/>
                    <Label  Grid.Row="1" Grid.Column="3" Content="Client Secret:" VerticalAlignment="Center"/>
                    <PasswordBox Grid.Row="1" Grid.Column="4" Name="TxtClientSecret" Margin="0,2,0,4"
                                 ToolTip="Copy from the Create App Registration screen — Copy Secret button"/>
                </Grid>
            </GroupBox>

            <!-- Buttons -->
            <Grid Grid.Row="3" Margin="0,2,0,8">
                <StackPanel HorizontalAlignment="Right" Orientation="Horizontal">
                    <Button Name="BtnClear"    Content="Clear Results"  Margin="0,0,6,0"/>
                    <Button Name="BtnStop"     Content="Stop"           IsEnabled="False" Margin="0,0,6,0"/>
                    <Button Name="BtnRunSetup" Content="Run Setup"
                            Background="#0064B4" Foreground="White" FontWeight="SemiBold" Width="110"/>
                    <Button Name="BtnClose"    Content="Close" Margin="16,0,0,0"
                            Background="#E1E4EE" Foreground="#1C1C20" BorderThickness="0"/>
                </StackPanel>
            </Grid>

            <!-- Results grid -->
            <DataGrid Grid.Row="4" Name="DgSetup" AutoGenerateColumns="False"
                      IsReadOnly="True" HeadersVisibility="Column"
                      GridLinesVisibility="Horizontal"
                      AlternatingRowBackground="#F5F6FA"
                      Background="White" BorderBrush="#D2D7E4"
                      RowHeight="28" FontSize="12">
                <DataGrid.Columns>
                    <DataGridTextColumn Header="Time"    Binding="{Binding Timestamp}" Width="80"/>
                    <DataGridTextColumn Header="Tenant"  Binding="{Binding Tenant}"    Width="200"/>
                    <DataGridTextColumn Header="Status"  Binding="{Binding Status}"    Width="100">
                        <DataGridTextColumn.CellStyle>
                            <Style TargetType="DataGridCell">
                                <Setter Property="FontWeight" Value="SemiBold"/>
                                <Setter Property="Padding"    Value="6,0"/>
                                <Style.Triggers>
                                    <DataTrigger Binding="{Binding Status}" Value="DONE">   <Setter Property="Foreground" Value="#107C10"/></DataTrigger>
                                    <DataTrigger Binding="{Binding Status}" Value="FAILED"> <Setter Property="Foreground" Value="#D13438"/></DataTrigger>
                                    <DataTrigger Binding="{Binding Status}" Value="SKIPPED"><Setter Property="Foreground" Value="#808080"/></DataTrigger>
                                    <DataTrigger Binding="{Binding Status}" Value="WORKING"><Setter Property="Foreground" Value="#0064B4"/></DataTrigger>
                                </Style.Triggers>
                            </Style>
                        </DataGridTextColumn.CellStyle>
                    </DataGridTextColumn>
                    <DataGridTextColumn Header="Message" Binding="{Binding Message}"   Width="*"/>
                </DataGrid.Columns>
            </DataGrid>

            <!-- Status bar -->
            <Border Grid.Row="5" Background="#EEF0F5" Padding="10,6" Margin="0,8,0,0"
                    BorderBrush="#D2D7E4" BorderThickness="1">
                <TextBlock Name="TxtSetupStatus" Text="Ready" Foreground="#646C78"/>
            </Border>
        </Grid>
    </DockPanel>
</Window>
'@

    $reader = New-Object System.Xml.XmlNodeReader $setupXaml
    $script:aosWindow = [Windows.Markup.XamlReader]::Load($reader)

    $script:aosCtrl = @{}
    $setupXaml.SelectNodes("//*[@Name]") | ForEach-Object { $script:aosCtrl[$_.Name] = $script:aosWindow.FindName($_.Name) }

    # Load icon
    $_iconFile = Join-Path $PSScriptRoot 'FlyMigration.ico'
    if (-not (Test-Path $_iconFile)) { $_iconFile = Join-Path $PSScriptRoot 'ourvolaris.png' }
    if (Test-Path $_iconFile) {
        $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
            [System.Uri]::new($_iconFile),
            [System.Windows.Media.Imaging.BitmapCreateOptions]::None,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $script:aosCtrl['ImgLogo'].Source = ($dec.Frames | Sort-Object PixelWidth | Select-Object -Last 1)
    }

    $script:aosResults    = New-Object System.Collections.ObjectModel.ObservableCollection[object]
    $script:aosCurrentProc = $null
    $script:aosPendingById = @{}
    $script:aosCtrl['DgSetup'].ItemsSource = $script:aosResults

    function Set-AosStatus($msg) { $script:aosCtrl['TxtSetupStatus'].Text = $msg }

    function Invoke-AosUIDispatch {
        $script:aosWindow.Dispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [action]{}
        )
    }

    function Find-AosNodeExe {
        try { $c = Get-Command node.exe -ErrorAction Stop; if ($c.Source) { return $c.Source } } catch { }
        foreach ($p in @(
            "$env:ProgramFiles\nodejs\node.exe",
            "${env:ProgramFiles(x86)}\nodejs\node.exe",
            "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
        )) { if ($p -and (Test-Path $p)) { return $p } }
        return $null
    }

    function Add-AosPendingRow($id, $tenant) {
        $row = [pscustomobject]@{
            Id        = $id
            Timestamp = (Get-Date).ToString('HH:mm:ss')
            Tenant    = $tenant
            Status    = 'WORKING'
            Message   = 'queued'
        }
        $script:aosResults.Add($row)
        $script:aosPendingById[$id] = $row
        $script:aosCtrl['DgSetup'].ScrollIntoView($row)
    }

    function Update-AosRow($id, $status, $message) {
        if ($script:aosPendingById.ContainsKey($id)) {
            $row = $script:aosPendingById[$id]
            $row.Timestamp = (Get-Date).ToString('HH:mm:ss')
            $row.Status    = $status
            $row.Message   = $message
            $script:aosCtrl['DgSetup'].Items.Refresh()
        }
    }

    function Invoke-AosConnectorLine($line) {
        try { $obj = $line | ConvertFrom-Json -ErrorAction Stop } catch {
            Set-AosStatus "(non-JSON) $line"
            return
        }
        if ($obj.event) {
            switch ($obj.event) {
                'info'     { Set-AosStatus $obj.message }
                'warn'     { Set-AosStatus "WARN: $($obj.message)" }
                'error'    { Set-AosStatus "ERROR: $($obj.message)" }
                'fatal'    { Set-AosStatus "FATAL: $($obj.message)" }
                'login-ok' {
                    Set-AosStatus "Signed in. Session saved."
                    $script:aosCtrl['TxtAuthStatus'].Text = "Signed in. Session saved."
                }
                'done'     { Set-AosStatus "Setup complete." }
                default    { Set-AosStatus "$($obj.event): $($obj.message)" }
            }
            return
        }
        if ($obj.id -and $obj.status) {
            Update-AosRow $obj.id $obj.status $obj.message
        }
    }

    function Invoke-AosConnector {
        param(
            [Parameter(Mandatory)][string]$Mode,
            [string[]]$StdinLines = @(),
            [string]$DisplayName  = ''
        )

        $node = Find-AosNodeExe
        if (-not $node) {
            [System.Windows.MessageBox]::Show(
                "Node.js was not found.`nInstall Node 18+ from https://nodejs.org and reopen.",
                "Node.js missing", 'OK', 'Error') | Out-Null
            return $false
        }
        if (-not (Test-Path $script:aosSetupConnectorJs)) {
            [System.Windows.MessageBox]::Show(
                "fly-connector.js not found: $script:aosSetupConnectorJs",
                "Connector missing", 'OK', 'Error') | Out-Null
            return $false
        }

        $argList = @("`"$($script:aosSetupConnectorJs)`"", "--mode=$Mode")
        if ($DisplayName) { $argList += "--display-name=$($DisplayName -replace '[^A-Za-z0-9._-]','_')" }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $node
        $psi.WorkingDirectory       = $PSScriptRoot
        $psi.Arguments              = $argList -join ' '
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.RedirectStandardInput  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.EnableRaisingEvents = $true

        Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action {
            param($src, $e)
            if (-not $e.Data) { return }
            $line = $e.Data
            $script:aosWindow.Dispatcher.Invoke([action]{ Invoke-AosConnectorLine $line })
        } | Out-Null

        Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action {
            param($src, $e)
            if (-not $e.Data) { return }
            $line = $e.Data
            $script:aosWindow.Dispatcher.Invoke([action]{ Set-AosStatus "stderr: $line" })
        } | Out-Null

        $script:aosCurrentProc = $proc
        $null = $proc.Start()
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        foreach ($line in $StdinLines) { $proc.StandardInput.WriteLine($line) }
        $proc.StandardInput.Close()

        while (-not $proc.HasExited) {
            Invoke-AosUIDispatch
            Start-Sleep -Milliseconds 100
        }
        Start-Sleep -Milliseconds 250
        Invoke-AosUIDispatch

        Get-EventSubscriber | Where-Object SourceObject -eq $proc | Unregister-Event
        $script:aosCurrentProc = $null
        return ($proc.ExitCode -eq 0)
    }

    # ── Auto-derive profile name from display name ────────────────────────────
    $script:aosCtrl['TxtDisplayName'].Add_TextChanged({
        $dn = $script:aosCtrl['TxtDisplayName'].Text.Trim()
        $current = $script:aosCtrl['TxtAppProfileName'].Text
        # Only auto-update if it still looks auto-generated (ends with " App" or is empty)
        if ([string]::IsNullOrWhiteSpace($current) -or $current -match ' App$') {
            if ($dn) { $script:aosCtrl['TxtAppProfileName'].Text = "$dn App" }
        }
    })

    # ── Sign In ───────────────────────────────────────────────────────────────
    $script:aosCtrl['BtnSignIn'].Add_Click({
        $script:aosCtrl['BtnSignIn'].IsEnabled    = $false
        $script:aosCtrl['BtnRunSetup'].IsEnabled  = $false
        Set-AosStatus "Launching browser for AOS sign-in..."
        try {
            Invoke-AosConnector -Mode 'login' | Out-Null
        } finally {
            $script:aosCtrl['BtnSignIn'].IsEnabled   = $true
            $script:aosCtrl['BtnRunSetup'].IsEnabled = $true
        }
    })

    # ── Clear results ─────────────────────────────────────────────────────────
    $script:aosCtrl['BtnClear'].Add_Click({
        $script:aosResults.Clear()
        $script:aosPendingById.Clear()
        Set-AosStatus "Cleared."
    })

    # ── Stop ──────────────────────────────────────────────────────────────────
    $script:aosCtrl['BtnStop'].Add_Click({
        if ($script:aosCurrentProc -and -not $script:aosCurrentProc.HasExited) {
            try { $script:aosCurrentProc.Kill() } catch { }
            Set-AosStatus "Stopped."
        }
    })

    # ── Run Setup ─────────────────────────────────────────────────────────────
    $script:aosCtrl['BtnRunSetup'].Add_Click({
        $displayName = $script:aosCtrl['TxtDisplayName'].Text.Trim()
        $searchCode  = $script:aosCtrl['TxtSearchCode'].Text.Trim()
        $appProfile  = $script:aosCtrl['TxtAppProfileName'].Text.Trim()
        $clientId    = $script:aosCtrl['TxtClientId'].Text.Trim()
        $clientSecret = $script:aosCtrl['TxtClientSecret'].Password

        if ([string]::IsNullOrWhiteSpace($displayName) -or
            [string]::IsNullOrWhiteSpace($searchCode)  -or
            [string]::IsNullOrWhiteSpace($appProfile)  -or
            [string]::IsNullOrWhiteSpace($clientId)    -or
            [string]::IsNullOrWhiteSpace($clientSecret)) {
            [System.Windows.MessageBox]::Show(
                "All fields are required:`n• Display Name`n• Search Code`n• Profile Name`n• Client ID`n• Client Secret",
                "Validation", 'OK', 'Warning') | Out-Null
            return
        }

        $id = [guid]::NewGuid().ToString('N').Substring(0, 8)
        $task = [pscustomobject]@{
            id                = $id
            tenantDisplayName = $displayName
            tenantSearch      = $searchCode
            appProfileName    = $appProfile
            clientId          = $clientId
            clientSecret      = $clientSecret
        }

        Add-AosPendingRow $id $displayName
        $stdinLines = @($task | ConvertTo-Json -Compress)

        # Persist display name + search code to shared config
        Update-SharedConfig @{
            TenantName   = $displayName
            TenantSearch = $searchCode
        }

        $script:aosCtrl['BtnRunSetup'].IsEnabled = $false
        $script:aosCtrl['BtnSignIn'].IsEnabled   = $false
        $script:aosCtrl['BtnStop'].IsEnabled     = $true
        Set-AosStatus "Running setup..."
        try {
            Invoke-AosConnector -Mode 'setup' -StdinLines $stdinLines -DisplayName $displayName | Out-Null
        } finally {
            $script:aosCtrl['BtnRunSetup'].IsEnabled = $true
            $script:aosCtrl['BtnSignIn'].IsEnabled   = $true
            $script:aosCtrl['BtnStop'].IsEnabled     = $false
        }
    })

    $script:aosCtrl['BtnClose'].Add_Click({ $script:aosWindow.Close() })

    # ── Pre-fill from shared config ───────────────────────────────────────────
    $_sc = Read-SharedConfig
    if ($_sc.TenantName)   { $script:aosCtrl['TxtDisplayName'].Text  = $_sc.TenantName }
    if ($_sc.TenantSearch) { $script:aosCtrl['TxtSearchCode'].Text   = $_sc.TenantSearch }
    if ($_sc.TenantName)   { $script:aosCtrl['TxtAppProfileName'].Text = "$($_sc.TenantName) App" }
    if ($_sc.TargetAppId)  { $script:aosCtrl['TxtClientId'].Text     = $_sc.TargetAppId }

    # Session status
    $authFile = Join-Path $PSScriptRoot 'auth\storageState.json'
    if (Test-Path $authFile) {
        $script:aosCtrl['TxtAuthStatus'].Text = "Previous session found. Sign in again only if expired."
    }

    [void]$script:aosWindow.ShowDialog()
}

# ═════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ═════════════════════════════════════════════════════════════════════════════
function Show-MainMenu {
    $MenuForm = New-Object System.Windows.Forms.Form
    $MenuForm.Text            = "AvePoint Fly - Select Operation"
    $MenuForm.ClientSize      = [System.Drawing.Size]::new(500, 500)
    $MenuForm.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $MenuForm.BackColor       = $clrBg
    $MenuForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $MenuForm.MaximizeBox     = $false
    $MenuForm.Font            = $FontBody

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(500, 60); $hdr.Dock = [System.Windows.Forms.DockStyle]::Top; $hdr.BackColor = $clrAccent
    $MenuForm.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 40
    $hdrTitle = New-Object System.Windows.Forms.Label
    $hdrTitle.Text      = "  Fly Migration Toolkit"
    $hdrTitle.Font      = $FontTitle
    $hdrTitle.ForeColor = [System.Drawing.Color]::White
    $hdrTitle.Location  = [System.Drawing.Point]::new($_hdrX, 15); $hdrTitle.AutoSize = $true
    $hdr.Controls.Add($hdrTitle)

    $btnWidth = 380; $btnHeight = 50; $btnX = 60; $startY = 90; $spacing = 70

    $btn1 = New-Object System.Windows.Forms.Button
    $btn1.Text = "1. Create App Registration"
    $btn1.Font = $FontBold; $btn1.Location = [System.Drawing.Point]::new($btnX, $startY)
    $btn1.Size = [System.Drawing.Size]::new($btnWidth, $btnHeight)
    $btn1.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn1.FlatAppearance.BorderSize = 0; $btn1.BackColor = $clrAccent
    $btn1.ForeColor = [System.Drawing.Color]::White; $btn1.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn1)

    $btn2 = New-Object System.Windows.Forms.Button
    $btn2.Text = "2. Setup AOS Tenant & App"
    $btn2.Font = $FontBold; $btn2.Location = [System.Drawing.Point]::new($btnX, $startY + $spacing)
    $btn2.Size = [System.Drawing.Size]::new($btnWidth, $btnHeight)
    $btn2.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn2.FlatAppearance.BorderSize = 0; $btn2.BackColor = $clrAccent
    $btn2.ForeColor = [System.Drawing.Color]::White; $btn2.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn2)

    $btn3 = New-Object System.Windows.Forms.Button
    $btn3.Text = "3. Create Connections"
    $btn3.Font = $FontBold; $btn3.Location = [System.Drawing.Point]::new($btnX, $startY + ($spacing * 2))
    $btn3.Size = [System.Drawing.Size]::new($btnWidth, $btnHeight)
    $btn3.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn3.FlatAppearance.BorderSize = 0; $btn3.BackColor = $clrAccent
    $btn3.ForeColor = [System.Drawing.Color]::White; $btn3.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn3)

    $btn4 = New-Object System.Windows.Forms.Button
    $btn4.Text = "4. Create and Load Mapping Files"
    $btn4.Font = $FontBold; $btn4.Location = [System.Drawing.Point]::new($btnX, $startY + ($spacing * 3))
    $btn4.Size = [System.Drawing.Size]::new($btnWidth, $btnHeight)
    $btn4.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn4.FlatAppearance.BorderSize = 0; $btn4.BackColor = $clrAccent
    $btn4.ForeColor = [System.Drawing.Color]::White; $btn4.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn4)

    $btn5 = New-Object System.Windows.Forms.Button
    $btn5.Text = "5. View Migration Reports"
    $btn5.Font = $FontBold; $btn5.Location = [System.Drawing.Point]::new($btnX, $startY + ($spacing * 4))
    $btn5.Size = [System.Drawing.Size]::new($btnWidth, $btnHeight)
    $btn5.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn5.FlatAppearance.BorderSize = 0; $btn5.BackColor = $clrAccent
    $btn5.ForeColor = [System.Drawing.Color]::White; $btn5.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btn5)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"
    $btnClose.Font = $FontBold; $btnClose.Location = [System.Drawing.Point]::new($btnX, $startY + ($spacing * 5))
    $btnClose.Size = [System.Drawing.Size]::new($btnWidth, 30)
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(225, 228, 238)
    $btnClose.ForeColor = $clrText; $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $MenuForm.Controls.Add($btnClose)

    $script:SelectedOperation = $null

    $btn1.Add_Click({    $script:SelectedOperation = "AppReg";      $MenuForm.Close() })
    $btn2.Add_Click({    $script:SelectedOperation = "AosSetup";    $MenuForm.Close() })
    $btn3.Add_Click({    $script:SelectedOperation = "Connections";  $MenuForm.Close() })
    $btn4.Add_Click({    $script:SelectedOperation = "Mapping";      $MenuForm.Close() })
    $btn5.Add_Click({    $script:SelectedOperation = "Reporting";    $MenuForm.Close() })
    $btnClose.Add_Click({ $script:SelectedOperation = $null;         $MenuForm.Close() })

    $MenuForm.ShowDialog() | Out-Null
    return $script:SelectedOperation
}

# ═════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═════════════════════════════════════════════════════════════════════════════
$operation = Show-MainMenu
while ($null -ne $operation) {
    switch ($operation) {
        "AppReg"      { Show-AppRegistrationForm  }
        "AosSetup"    { Show-AosSetupForm          }
        "Connections" { Show-ConnectionsForm       }
        "Mapping"     { Show-MigrationRunnerForm   }
        "Reporting"   { Show-ReportingForm         }
    }
    $operation = Show-MainMenu
}
