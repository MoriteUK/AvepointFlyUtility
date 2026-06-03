#Requires -Version 7.0
# M365 Discovery Launcher — standalone GUI wrapper for search-domain.ps1

$libPath    = Join-Path $PSScriptRoot 'lib.ps1'
$_libLoaded = $false
if (Test-Path $libPath) {
    try {
        . $libPath
        $_libLoaded = $true
    } catch {
        # lib.ps1 crashed before our log is set up — write to a temp file so we can diagnose
        $_crashLog = Join-Path $env:TEMP "discovery-menu-libcrash-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        "lib.ps1 load FAILED: $($_.Exception.Message)`nStack: $($_.ScriptStackTrace)" |
            Set-Content -Path $_crashLog -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}
$_settingsPath = Join-Path $PSScriptRoot 'settings.ps1'
if (Test-Path $_settingsPath) { try { . $_settingsPath } catch {} }

if (-not $_libLoaded) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
    $clrBg     = [System.Drawing.Color]::FromArgb(240, 242, 247)
    $clrAccent = [System.Drawing.Color]::FromArgb(0, 100, 180)
    $clrText   = [System.Drawing.Color]::FromArgb(28, 28, 32)
    $clrMuted  = [System.Drawing.Color]::FromArgb(100, 108, 120)
    $clrLogBg  = [System.Drawing.Color]::FromArgb(26, 27, 38)
    $FontBody  = New-Object System.Drawing.Font('Segoe UI', 9)
    $FontBold  = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $FontTitle = $FontTile
    $AnchorTL  = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $AnchorTLR = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    function Add-HeaderLogo { param($Header, [int]$LogoH = 34) return ($LogoH + 16) }
    function New-Lbl {
        param($Parent, [string]$Text, [int]$X, [int]$Y, [bool]$Bold = $false)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $Text; $l.Location = [System.Drawing.Point]::new($X, $Y)
        $l.AutoSize = $true; $l.Font = if ($Bold) { $FontBold } else { $FontBody }
        $l.ForeColor = $clrText; $Parent.Controls.Add($l); return $l
    }
    function New-TB {
        param($Parent, [int]$X, [int]$Y, [int]$W, [int]$RightMargin = -1,
              [bool]$Password = $false, [string]$Default = "")
        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Location = [System.Drawing.Point]::new($X, $Y); $tb.Size = [System.Drawing.Size]::new($W, 24)
        $tb.Font = $FontBody; $tb.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $tb.Text = $Default
        if ($RightMargin -ge 0) { $tb.Anchor = $AnchorTLR; $tb.Width = $Parent.Width - $X - $RightMargin }
        else { $tb.Anchor = $AnchorTL }
        $Parent.Controls.Add($tb); return $tb
    }
    function New-Btn {
        param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$W = 140, [int]$H = 30,
              [bool]$Primary = $true, [bool]$AnchorRight = $false)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $Text; $b.Location = [System.Drawing.Point]::new($X, $Y)
        $b.Size = [System.Drawing.Size]::new($W, $H); $b.Font = $FontBold
        $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $b.FlatAppearance.BorderSize = 0
        $b.BackColor = if ($Primary) { $clrAccent } else { [System.Drawing.Color]::FromArgb(225, 228, 238) }
        $b.ForeColor = if ($Primary) { [System.Drawing.Color]::White } else { $clrText }
        $b.Cursor = [System.Windows.Forms.Cursors]::Hand
        $Parent.Controls.Add($b); return $b
    }
}

$OutputDir    = 'C:\Users\Andy White\Volaris Group\GRP Data Security (Volaris Consolidated) - M365 Migrations\2. InProgress Migrations'
$SingleScript = Join-Path $PSScriptRoot 'search-domain.ps1'
$MultiScript  = Join-Path $PSScriptRoot 'run-multiple-domains.ps1'

# ── File logging (shadows lib.ps1 Write-Log which requires $script:rtbLog) ───
$_logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $_logDir)) { New-Item -ItemType Directory -Path $_logDir -Force | Out-Null }
$script:LogFile = Join-Path $_logDir "discovery-menu-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')  [$($Level.PadRight(5))]  $Msg"
    Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}
Write-Log "=== discovery-menu.ps1 started  PID=$PID  PSVersion=$($PSVersionTable.PSVersion) ==="
Write-Log "ScriptRoot : $PSScriptRoot"
Write-Log "lib.ps1    : $libPath  exists=$(Test-Path $libPath)  loaded=$_libLoaded"
if (-not $_libLoaded -and (Test-Path $libPath)) {
    $_crash = Join-Path $env:TEMP "discovery-menu-libcrash-*.log" |
              Resolve-Path -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1
    if ($_crash) { Write-Log "lib.ps1 crash log: $_crash" 'WARN' }
}
Write-Log "SingleScript: $SingleScript  exists=$(Test-Path $SingleScript)"
Write-Log "MultiScript : $MultiScript  exists=$(Test-Path $MultiScript)"
Write-Log "OutputDir   : $OutputDir"

function Show-DiscoveryMenu {
    Write-Log 'Show-DiscoveryMenu: building form'

    $script:discProcess   = $null
    $script:discTimer     = $null
    $script:searchLogFile = $null
    $script:searchLogPos  = 0

    # Persist the toolkit folder so ad-hoc scripts (e.g. Get-SPOSiteCache.ps1) can find it.
    if ($_libLoaded -and (Get-Command Update-SharedConfig -ErrorAction SilentlyContinue)) {
        try { Update-SharedConfig @{ ToolkitPath = $PSScriptRoot } } catch {}
    }

    # Load saved output directory from shared config (overrides the script-level default)
    if ($_libLoaded -and (Get-Command Read-SharedConfig -ErrorAction SilentlyContinue)) {
        $savedCfg = try { Read-SharedConfig } catch { $null }
        if ($savedCfg -and $savedCfg.PSObject.Properties['DiscoveryOutputPath'] -and
            -not [string]::IsNullOrWhiteSpace($savedCfg.DiscoveryOutputPath)) {
            $OutputDir = $savedCfg.DiscoveryOutputPath
        }
    }

    # ── Load domain list from domains.json ────────────────────────────────────
    $domainVbuMap   = @{}   # domain (lower) → vbuId string
    $domainListSorted = @()
    $domainsJsonPath  = Join-Path $PSScriptRoot 'domains.json'
    if (Test-Path $domainsJsonPath) {
        try {
            $domainEntries = @(Get-Content $domainsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json)
            foreach ($e in $domainEntries) {
                $d = if ($e.PSObject.Properties['domain']) { [string]$e.domain } else { $null }
                $v = if ($e.PSObject.Properties['vbuId'])  { [string]$e.vbuId  } else { '' }
                if ($d) { $domainVbuMap[$d.ToLower()] = $v }
            }
            $domainListSorted = @($domainVbuMap.Keys | Sort-Object)
            Write-Log "Loaded $($domainListSorted.Count) domain(s) from domains.json"
        } catch {
            Write-Log "Could not load domains.json: $($_.Exception.Message)" 'WARN'
        }
    } else {
        Write-Log "domains.json not found — domain dropdown will be empty" 'WARN'
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'M365 Discovery Launcher'
    $form.ClientSize      = [System.Drawing.Size]::new(540, 900)
    $form.MinimumSize     = [System.Drawing.Size]::new(540, 700)
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.BackColor       = $clrBg
    $form.Font            = $FontBody
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.MaximizeBox     = $true
    $_ico = Join-Path $PSScriptRoot 'FlyMigration.ico'
    if (Test-Path $_ico) { $form.Icon = [System.Drawing.Icon]::new($_ico) }

    # ── Header ────────────────────────────────────────────────────────────────
    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Size = [System.Drawing.Size]::new(540, 56); $hdr.Dock = [System.Windows.Forms.DockStyle]::Top
    $hdr.BackColor = $clrAccent
    $form.Controls.Add($hdr)
    $_hdrX = Add-HeaderLogo $hdr 36
    $hdrLbl = New-Object System.Windows.Forms.Label
    $hdrLbl.Text = '  M365 Discovery'; $hdrLbl.Font = $FontTitle
    $hdrLbl.ForeColor = [System.Drawing.Color]::White
    $hdrLbl.Location  = [System.Drawing.Point]::new($_hdrX, 0)
    $hdrLbl.Size      = [System.Drawing.Size]::new(440, 56)
    $hdrLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdr.Controls.Add($hdrLbl)

    $btnGear = New-Object System.Windows.Forms.Button
    $btnGear.BackColor = $clrAccent; $btnGear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnGear.FlatAppearance.BorderSize = 0
    $btnGear.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::$clrAccentHover
    $btnGear.Size = [System.Drawing.Size]::new(38, 38); $btnGear.Location = [System.Drawing.Point]::new(494, 9)
    $btnGear.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnGear.Add_Click({ if (Get-Command Show-SettingsDialog -ErrorAction SilentlyContinue) { Show-SettingsDialog } })
    if ($script:GearBitmap) { $btnGear.Image = $script:GearBitmap; $btnGear.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter }
    else { $btnGear.Text = [char]0x2699; $btnGear.Font = New-Object System.Drawing.Font('Segoe UI', 16); $btnGear.ForeColor = [System.Drawing.Color]::White }
    $hdr.Controls.Add($btnGear)

    # ── Footer ────────────────────────────────────────────────────────────────
    $footer = New-Object System.Windows.Forms.Panel
    $footer.Height = 46; $footer.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footer.BackColor = [System.Drawing.Color]::$clrFooter
    $form.Controls.Add($footer)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Close'; $btnClose.Size = [System.Drawing.Size]::new(90, 30)
    $btnClose.Location = [System.Drawing.Point]::new(444, 8)
    $btnClose.BackColor = [System.Drawing.Color]::$clrCloseRed
    $btnClose.ForeColor = [System.Drawing.Color]::White; $btnClose.Font = $FontBold
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand; $btnClose.Add_Click({ $form.Close() })
    $footer.Controls.Add($btnClose)
    $footer.Add_SizeChanged({ $btnClose.Left = $footer.Width - 100 }.GetNewClosure())

    # ── Helpers ───────────────────────────────────────────────────────────────
    $lx = 20; $rw = 500; $y = 72

    function MkLabel { param([string]$Text,[int]$X,[int]$Y,[bool]$Bold=$false)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $Text; $l.Location = [System.Drawing.Point]::new($X,$Y); $l.AutoSize = $true
        $l.ForeColor = $clrText; if ($Bold) { $l.Font = $FontBold }
        $form.Controls.Add($l); return $l }
    function MkCheck { param([string]$Text,[int]$X,[int]$Y,[bool]$Chk=$false)
        $c = New-Object System.Windows.Forms.CheckBox
        $c.Text = $Text; $c.Location = [System.Drawing.Point]::new($X,$Y); $c.AutoSize = $true
        $c.ForeColor = $clrText; $c.Checked = $Chk
        $form.Controls.Add($c); return $c }
    function MkSep { param([int]$Y)
        $p = New-Object System.Windows.Forms.Panel
        $p.Location = [System.Drawing.Point]::new($lx,$Y); $p.Size = [System.Drawing.Size]::new($rw,1)
        $p.BackColor = [System.Drawing.Color]::FromArgb(50,60,85); $form.Controls.Add($p); return $p }

    # ── Scan scope radios ─────────────────────────────────────────────────────
    $null = MkLabel 'Scan scope:' $lx ($y+2) $true
    $radSingle = New-Object System.Windows.Forms.RadioButton
    $radSingle.Text = 'Single domain'; $radSingle.Location = [System.Drawing.Point]::new(110,$y)
    $radSingle.AutoSize = $true; $radSingle.ForeColor = $clrText; $radSingle.Checked = $true
    $form.Controls.Add($radSingle)
    $radMulti = New-Object System.Windows.Forms.RadioButton
    $radMulti.Text = 'Multiple domains'; $radMulti.Location = [System.Drawing.Point]::new(258,$y)
    $radMulti.AutoSize = $true; $radMulti.ForeColor = $clrText
    $form.Controls.Add($radMulti)
    $y += 32

    # ── Single domain panel (28px tall) ───────────────────────────────────────
    $pnlSingle = New-Object System.Windows.Forms.Panel
    $pnlSingle.Location = [System.Drawing.Point]::new($lx,$y); $pnlSingle.Size = [System.Drawing.Size]::new($rw,28)
    $pnlSingle.BackColor = $clrBg
    $form.Controls.Add($pnlSingle)
    $lbDom = New-Object System.Windows.Forms.Label
    $lbDom.Text = 'Domain:'; $lbDom.Location = [System.Drawing.Point]::new(0,6); $lbDom.AutoSize = $true
    $lbDom.Font = $FontBold; $lbDom.ForeColor = $clrText; $pnlSingle.Controls.Add($lbDom)
    $cmbDomain = New-Object System.Windows.Forms.ComboBox
    $cmbDomain.Location        = [System.Drawing.Point]::new(115, 2)
    $cmbDomain.Size            = [System.Drawing.Size]::new(280, 24)
    $cmbDomain.BackColor       = [System.Drawing.Color]::FromArgb(40, 50, 70)
    $cmbDomain.ForeColor       = [System.Drawing.Color]::FromArgb(235, 195, 80)
    $cmbDomain.DropDownStyle   = [System.Windows.Forms.ComboBoxStyle]::DropDown
    $cmbDomain.AutoCompleteMode   = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend
    $cmbDomain.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::ListItems
    foreach ($d in $domainListSorted) { $cmbDomain.Items.Add($d) | Out-Null }
    $pnlSingle.Controls.Add($cmbDomain)

    # ── Multiple domains panel (100px tall — multiline text box) ──────────────
    $pnlMulti = New-Object System.Windows.Forms.Panel
    $pnlMulti.Location = [System.Drawing.Point]::new($lx,$y); $pnlMulti.Size = [System.Drawing.Size]::new($rw,100)
    $pnlMulti.BackColor = $clrBg; $pnlMulti.Visible = $false
    $form.Controls.Add($pnlMulti)
    $lbDoms = New-Object System.Windows.Forms.Label
    $lbDoms.Text = 'Domains:'; $lbDoms.Location = [System.Drawing.Point]::new(0,4); $lbDoms.AutoSize = $true
    $lbDoms.Font = $FontBold; $lbDoms.ForeColor = $clrText; $pnlMulti.Controls.Add($lbDoms)
    $lbDomsHint = New-Object System.Windows.Forms.Label
    $lbDomsHint.Text = '(one per line)'; $lbDomsHint.Location = [System.Drawing.Point]::new(115,6)
    $lbDomsHint.AutoSize = $true; $lbDomsHint.ForeColor = $clrMuted; $pnlMulti.Controls.Add($lbDomsHint)
    $txtDomains = New-Object System.Windows.Forms.TextBox
    $txtDomains.Location = [System.Drawing.Point]::new(0,24); $txtDomains.Size = [System.Drawing.Size]::new($rw,76)
    $txtDomains.Multiline = $true; $txtDomains.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $txtDomains.BackColor = [System.Drawing.Color]::FromArgb(40,50,70); $txtDomains.ForeColor = [System.Drawing.Color]::FromArgb(235,195,80)
    $txtDomains.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtDomains.Font = New-Object System.Drawing.Font('Consolas', 9)
    $pnlMulti.Controls.Add($txtDomains)

    $y += 36    # single-panel gap (28px panel + 8px); toggle handler adds 72px more for multi mode

    # ── VBU ID — sits directly below the domain input ────────────────────────
    $lbBuid = MkLabel 'VBU ID:' $lx ($y+4)
    $txtBuid = New-Object System.Windows.Forms.TextBox
    $txtBuid.Location = [System.Drawing.Point]::new($lx+115,$y+1); $txtBuid.Size = [System.Drawing.Size]::new(110,24)
    $txtBuid.BackColor = [System.Drawing.Color]::FromArgb(40,50,70); $txtBuid.ForeColor = [System.Drawing.Color]::FromArgb(235,195,80)
    $txtBuid.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    try { $txtBuid.PlaceholderText = 'optional' } catch {}
    $form.Controls.Add($txtBuid)

    # Auto-fill VBU ID when a domain is chosen — registered here so $txtBuid is in scope
    $cmbDomain.Add_SelectedIndexChanged({
        $sel = [string]$cmbDomain.SelectedItem
        if ($sel -and $domainVbuMap.ContainsKey($sel.ToLower())) {
            $txtBuid.Text = $domainVbuMap[$sel.ToLower()]
        }
    }.GetNewClosure())
    $cmbDomain.Add_Leave({
        $typed = $cmbDomain.Text.Trim().ToLower()
        if ($typed -and $domainVbuMap.ContainsKey($typed)) {
            $txtBuid.Text = $domainVbuMap[$typed]
        }
    }.GetNewClosure())

    $lbBuidHint = New-Object System.Windows.Forms.Label
    $lbBuidHint.Text = '(filters by ExtensionAttribute7)'; $lbBuidHint.Location = [System.Drawing.Point]::new($lx+233,$y+4)
    $lbBuidHint.AutoSize = $true; $lbBuidHint.ForeColor = $clrMuted; $form.Controls.Add($lbBuidHint)
    $y += 38

    # ── Separator + Options ───────────────────────────────────────────────────
    $sep1Ctrl   = MkSep $y; $y += 12
    $lblOptions = MkLabel 'Options' $lx $y $true; $y += 26

    $chkSkipPP   = MkCheck 'Skip Power Platform  (recommended for unattended / batch runs)' ($lx+8) $y $true;  $y += 26
    $chkHybrid   = MkCheck 'Hybrid  (includes on-prem Active Directory scanning)'           ($lx+8) $y;        $y += 26
    $chkMembers  = MkCheck 'Include Members  (distribution groups, M365 Groups)'            ($lx+8) $y;        $y += 26
    $chkContinue = MkCheck 'Continue on error  (skip failed domains in multi-domain run)'   ($lx+8) $y
    $chkContinue.Visible = $false; $y += 26

    # ── Output folder (editable, persisted to shared config) ─────────────────
    $sep2Ctrl  = MkSep $y; $y += 10
    $lbOutDir  = MkLabel 'Output folder:' $lx ($y+4) $true

    $txtOutDir = New-Object System.Windows.Forms.TextBox
    $txtOutDir.Location    = [System.Drawing.Point]::new($lx + 105, $y + 1)
    $txtOutDir.Size        = [System.Drawing.Size]::new(340, 24)
    $txtOutDir.Font        = $FontBody
    $txtOutDir.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtOutDir.Text        = $OutputDir
    $form.Controls.Add($txtOutDir)

    $btnBrowseOut = New-Object System.Windows.Forms.Button
    $btnBrowseOut.Text     = '...'
    $btnBrowseOut.Location = [System.Drawing.Point]::new($lx + 452, $y)
    $btnBrowseOut.Size     = [System.Drawing.Size]::new(28, 24)
    $btnBrowseOut.Font     = $FontBody
    $btnBrowseOut.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowseOut.FlatAppearance.BorderSize = 1
    $btnBrowseOut.Cursor   = [System.Windows.Forms.Cursors]::Hand
    $form.Controls.Add($btnBrowseOut)

    $btnBrowseOut.Add_Click({
        $fbd = [System.Windows.Forms.FolderBrowserDialog]::new()
        $fbd.Description  = 'Select the base output folder for discovery results'
        $fbd.SelectedPath = if (Test-Path $txtOutDir.Text -ErrorAction SilentlyContinue) { $txtOutDir.Text } else { $env:USERPROFILE }
        if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtOutDir.Text = $fbd.SelectedPath
            if ($_libLoaded -and (Get-Command Update-SharedConfig -ErrorAction SilentlyContinue)) {
                try { Update-SharedConfig @{ DiscoveryOutputPath = $fbd.SelectedPath } } catch {}
            }
        }
    }.GetNewClosure())

    $txtOutDir.Add_Leave({
        $p = $txtOutDir.Text.Trim()
        if ($p -and $_libLoaded -and (Get-Command Update-SharedConfig -ErrorAction SilentlyContinue)) {
            try { Update-SharedConfig @{ DiscoveryOutputPath = $p } } catch {}
        }
    }.GetNewClosure())

    $y += 32

    # ── Run / Stop buttons ────────────────────────────────────────────────────
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = 'Run Discovery'; $btnRun.Location = [System.Drawing.Point]::new($lx,$y)
    $btnRun.Size = [System.Drawing.Size]::new(160,36)
    $btnRun.BackColor = [System.Drawing.Color]::FromArgb(18,140,60)
    $btnRun.ForeColor = [System.Drawing.Color]::White; $btnRun.Font = $FontBold
    $btnRun.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnRun.FlatAppearance.BorderSize = 0
    $btnRun.Cursor = [System.Windows.Forms.Cursors]::Hand; $form.Controls.Add($btnRun)

    $btnStop = New-Object System.Windows.Forms.Button
    $btnStop.Text = 'Stop'; $btnStop.Location = [System.Drawing.Point]::new($lx+170,$y)
    $btnStop.Size = [System.Drawing.Size]::new(80,36)
    $btnStop.BackColor = [System.Drawing.Color]::FromArgb(180,45,45)
    $btnStop.ForeColor = [System.Drawing.Color]::White; $btnStop.Font = $FontBold
    $btnStop.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnStop.FlatAppearance.BorderSize = 0
    $btnStop.Cursor = [System.Windows.Forms.Cursors]::Hand; $btnStop.Enabled = $false
    $form.Controls.Add($btnStop)

    $btnClearLog = New-Object System.Windows.Forms.Button
    $btnClearLog.Text = 'Clear Log'; $btnClearLog.Location = [System.Drawing.Point]::new($lx+260,$y)
    $btnClearLog.Size = [System.Drawing.Size]::new(90,36)
    $btnClearLog.BackColor = [System.Drawing.Color]::FromArgb(80,90,110)
    $btnClearLog.ForeColor = [System.Drawing.Color]::White; $btnClearLog.Font = $FontBold
    $btnClearLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClearLog.FlatAppearance.BorderSize = 0
    $btnClearLog.Cursor = [System.Windows.Forms.Cursors]::Hand
    $form.Controls.Add($btnClearLog)

    $y += 46

    # ── Output log ────────────────────────────────────────────────────────────
    $rtbLog = New-Object System.Windows.Forms.RichTextBox
    $rtbLog.Location    = [System.Drawing.Point]::new($lx,$y)
    $rtbLog.Size        = [System.Drawing.Size]::new($rw, $form.ClientSize.Height - $y - 60)
    $rtbLog.BackColor   = $clrLogBg
    $rtbLog.ForeColor   = [System.Drawing.Color]::FromArgb(200, 215, 235)
    $rtbLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $rtbLog.Font        = New-Object System.Drawing.Font('Consolas', 8.5)
    $rtbLog.ReadOnly    = $true
    $rtbLog.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $rtbLog.WordWrap    = $true
    $form.Controls.Add($rtbLog)

    # Registered here so $rtbLog is in scope when the closure is created.
    $btnClearLog.Add_Click({ $rtbLog.Clear() }.GetNewClosure())

    $form.Add_Resize({
        $newH = $form.ClientSize.Height - $rtbLog.Top - 60
        if ($newH -gt 80) { $rtbLog.Height = $newH }
        $rtbLog.Width = $form.ClientSize.Width - 40
    }.GetNewClosure())

    # ── Radio toggle ──────────────────────────────────────────────────────────
    # Shift amount = difference between multi-panel height (100px) and
    # single-panel height (28px), matching the $y += 36 / $y += 108 delta above.
    $script:discModeOffset = 0
    $toggleMode = {
        $mode = if ($radSingle.Checked) { 'Single' } else { 'Multi' }
        Write-Log "Scope toggled: $mode"
        $pnlSingle.Visible   = $radSingle.Checked
        $pnlMulti.Visible    = $radMulti.Checked
        $chkContinue.Visible = $radMulti.Checked

        $newOffset = if ($radMulti.Checked) { 72 } else { 0 }
        $delta = $newOffset - $script:discModeOffset
        if ($delta -ne 0) {
            $script:discModeOffset = $newOffset
            foreach ($ctrl in @($lbBuid, $txtBuid, $lbBuidHint,
                                $sep1Ctrl, $lblOptions,
                                $chkSkipPP, $chkHybrid, $chkMembers, $chkContinue,
                                $sep2Ctrl, $lbOutDir, $txtOutDir, $btnBrowseOut,
                                $btnRun, $btnStop, $btnClearLog, $rtbLog)) {
                $ctrl.Top += $delta
            }
            $newH = $form.ClientSize.Height - $rtbLog.Top - 60
            if ($newH -gt 80) { $rtbLog.Height = $newH }
        }
    }.GetNewClosure()

    $radSingle.Add_CheckedChanged({ & $toggleMode }.GetNewClosure())
    $radMulti.Add_CheckedChanged({  & $toggleMode }.GetNewClosure())

    # ── Output log file (separate from the menu's own log) ───────────────────
    $script:discLogFile = $null

    # Stored as a scriptblock variable so GetNewClosure() on nested closures can capture it.
    # A 'function' keyword definition lives in the scope's function table, not the variable
    # table, so it is invisible to closures created by GetNewClosure().
    $writeDiscLog = {
        param([string]$line)
        if ($script:discLogFile) {
            Add-Content -Path $script:discLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        $rtbLog.AppendText("$line`n")
        $rtbLog.ScrollToCaret()
    }.GetNewClosure()

    # ── Stop handler ──────────────────────────────────────────────────────────
    $btnStop.Add_Click({
        Write-Log 'Stop clicked'
        if ($script:discTimer -and $script:discTimer.Enabled) { $script:discTimer.Stop() }
        if ($script:discProcess -and -not $script:discProcess.HasExited) {
            try {
                $script:discProcess.Kill($true)  # $true = kill entire process tree
                Write-Log 'Process tree killed'
            } catch {
                Write-Log "Kill failed: $($_.Exception.Message)" 'WARN'
            }
        }
        & $writeDiscLog ''
        & $writeDiscLog '-- Discovery stopped by user --'
        $btnRun.Enabled = $true; $btnRun.Text = 'Run Discovery'
        $btnStop.Enabled = $false
    }.GetNewClosure())

    # ── Launch helper ─────────────────────────────────────────────────────────
    $buildAndLaunch = {
        param([string]$Cmd, [string]$LogEntry, [string]$WatchDir = '')
        # Copy into local scope so the nested timer-tick GetNewClosure() can capture it.
        $wdl = $writeDiscLog
        Write-Log "buildAndLaunch: $LogEntry  WatchDir='$WatchDir'"

        # Stop any existing run
        if ($script:discTimer  -and $script:discTimer.Enabled)           { $script:discTimer.Stop() }
        if ($script:discProcess -and -not $script:discProcess.HasExited) {
            try { $script:discProcess.Kill($true) } catch {}
        }

        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $script:discLogFile   = Join-Path (Join-Path $PSScriptRoot 'logs') "discovery-output-$stamp.log"
        $script:searchLogFile = $null
        $script:searchLogPos  = 0
        $rtbLog.Clear()
        $btnRun.Enabled = $false; $btnRun.Text = 'Running...'
        $btnStop.Enabled = $true

        try {
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Cmd))
            Write-Log "Launching pwsh.exe (UseShellExecute, minimized)"

            # UseShellExecute = $true gives the child its own console window so MSAL
            # uses that process's HWND for OAuth instead of finding this form's HWND.
            # Output is captured by tailing the _Search-M365Domain_*.log file that
            # search-domain.ps1 writes to the output folder.
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName        = 'pwsh.exe'
            $psi.Arguments       = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
            $psi.UseShellExecute = $true
            $psi.WindowStyle     = [System.Diagnostics.ProcessWindowStyle]::Minimized

            $proc = [System.Diagnostics.Process]::Start($psi)
            $script:discProcess = $proc
            Write-Log "Process started: PID=$($proc.Id)"

            & $wdl "=== Discovery started  $(Get-Date)  PID=$($proc.Id) ==="
            & $wdl "=== A browser sign-in window will open shortly — complete authentication there ==="
            if ($WatchDir) {
                & $wdl "=== Tailing log in: $WatchDir ==="
            } else {
                & $wdl "=== No watch directory set — log will not be shown here ==="
            }
            & $wdl ""

            $script:discTimer = New-Object System.Windows.Forms.Timer
            $script:discTimer.Interval = 500

            $timerWatchDir = $WatchDir
            $timerProc     = $proc
            $timerRunBtn   = $btnRun
            $timerStopBtn  = $btnStop

            # Helper: open the log file for shared-read and return all new content
            $readNew = {
                param([string]$path, [ref]$pos)
                if (-not (Test-Path $path -ErrorAction SilentlyContinue)) { return @() }
                $fs = [System.IO.File]::Open($path,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::ReadWrite)
                try {
                    if ($fs.Length -le $pos.Value) { return @() }
                    $fs.Position = $pos.Value
                    $sr    = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
                    $chunk = $sr.ReadToEnd()
                    $pos.Value = $fs.Length
                    return @($chunk -split "`r?`n" | Where-Object { $_ })
                } finally { $fs.Dispose() }
            }

            $script:discTimer.add_Tick({
                try {
                    # Locate the log file the first time it appears
                    if (-not $script:searchLogFile -and $timerWatchDir) {
                        $f = Get-ChildItem -Path $timerWatchDir -Filter '_Search-M365Domain_*.log' `
                                -File -ErrorAction SilentlyContinue |
                            Sort-Object LastWriteTime -Descending | Select-Object -First 1
                        if ($f) {
                            $script:searchLogFile = $f.FullName
                            $script:searchLogPos  = 0
                            & $wdl "=== Log: $($f.Name) ==="
                        }
                    }

                    # Stream new lines into the RTB
                    if ($script:searchLogFile) {
                        foreach ($l in (& $readNew $script:searchLogFile ([ref]$script:searchLogPos))) {
                            & $wdl $l
                        }
                    }

                    # Detect process exit
                    if ($timerProc.HasExited) {
                        $script:discTimer.Stop()
                        # Final drain
                        if ($script:searchLogFile) {
                            foreach ($l in (& $readNew $script:searchLogFile ([ref]$script:searchLogPos))) {
                                & $wdl $l
                            }
                        }
                        & $wdl ""
                        & $wdl "-- Discovery finished  exit=$($timerProc.ExitCode)  $(Get-Date) --"
                        Write-Log "Process exited: ExitCode=$($timerProc.ExitCode)"
                        $timerRunBtn.Enabled = $true; $timerRunBtn.Text = 'Run Discovery'
                        $timerStopBtn.Enabled = $false
                    }
                } catch {
                    Write-Log "Timer tick error: $($_.Exception.Message)" 'WARN'
                }
            }.GetNewClosure())

            $script:discTimer.Start()
            Write-Log 'Log-tail timer started'

        } catch {
            Write-Log "Launch failed: $($_.Exception.Message)" 'ERROR'
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to launch pwsh.exe:`n$($_.Exception.Message)", 'Launch Error','OK','Error') | Out-Null
            $btnRun.Enabled = $true; $btnRun.Text = 'Run Discovery'
            $btnStop.Enabled = $false
        }
    }.GetNewClosure()

    # ── Run handler ───────────────────────────────────────────────────────────
    $btnRun.Add_Click({
        $buid   = $txtBuid.Text.Trim()
        $escOut = $txtOutDir.Text.Trim() -replace "'","''"

        if ($radSingle.Checked) {
            $domain = $cmbDomain.Text.Trim().ToLower().TrimStart('@')
            if ([string]::IsNullOrWhiteSpace($domain)) {
                [System.Windows.Forms.MessageBox]::Show('Enter a domain name.','Missing Input','OK','Warning') | Out-Null; return
            }
            if (-not (Test-Path $SingleScript)) {
                [System.Windows.Forms.MessageBox]::Show("Script not found:`n$SingleScript",'Not Found','OK','Error') | Out-Null; return
            }
            Write-Log "Run (single): domain=$domain  SkipPP=$($chkSkipPP.Checked)  Hybrid=$($chkHybrid.Checked)  Members=$($chkMembers.Checked)  BUID='$buid'"
            $escS = $SingleScript -replace "'","''"
            $cmd  = "Set-Location '$escOut'; & '$escS' -Domain '$domain'"
            if ($chkHybrid.Checked)  { $cmd += ' -Hybrid' }
            if ($chkMembers.Checked) { $cmd += ' -IncludeMembers' }
            if ($chkSkipPP.Checked)  { $cmd += ' -SkipPowerPlatform' }
            if ($buid)               { $cmd += " -BusinessUnitId '$buid'" }
            $watchDir = Join-Path $txtOutDir.Text.Trim() ($domain -replace '[\\/:*?"<>|]', '_')
            & $buildAndLaunch $cmd "Single: $domain" $watchDir

        } else {
            # Parse the multiline textbox — skip blank lines and # comments
            $domains = @($txtDomains.Lines |
                ForEach-Object { $_.Trim().ToLower().TrimStart('@') } |
                Where-Object   { $_ -and -not $_.StartsWith('#') -and $_ -match '\.' })

            if ($domains.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    'Enter at least one domain name (one per line).','Missing Input','OK','Warning') | Out-Null; return
            }
            if (-not (Test-Path $MultiScript)) {
                [System.Windows.Forms.MessageBox]::Show("Script not found:`n$MultiScript",'Not Found','OK','Error') | Out-Null; return
            }
            # Build @('d1','d2',...) literal for the encoded command
            Write-Log "Run (multi): $($domains.Count) domains=[$($domains -join ',')]  SkipPP=$($chkSkipPP.Checked)  Hybrid=$($chkHybrid.Checked)  Members=$($chkMembers.Checked)  Continue=$($chkContinue.Checked)  BUID='$buid'"
            $arrayLiteral = "@('" + ($domains -join "','") + "')"
            $escM = $MultiScript -replace "'","''"
            $cmd  = "Set-Location '$escOut'; & '$escM' -Domains $arrayLiteral"
            if ($chkHybrid.Checked)   { $cmd += ' -Hybrid' }
            if ($chkMembers.Checked)  { $cmd += ' -IncludeMembers' }
            if ($chkSkipPP.Checked)   { $cmd += ' -SkipPowerPlatform' }
            if ($chkContinue.Checked) { $cmd += ' -ContinueOnError' }
            if ($buid)                { $cmd += " -BusinessUnitId '$buid'" }
            & $buildAndLaunch $cmd "Multi: $($domains.Count) domain(s) - $($domains -join ', ')" ''
        }
    }.GetNewClosure())

    $form.Add_Shown({
        Write-Log 'Form Shown event — calling BringToFront/Activate'
        $form.BringToFront()
        $form.Activate()
        Write-Log 'Form activated'
    }.GetNewClosure())

    $form.Add_FormClosing({
        param($s, $e)
        if ($script:discProcess -and -not $script:discProcess.HasExited) {
            $r = [System.Windows.Forms.MessageBox]::Show(
                "Discovery is still running. Stop it and close?",
                'Discovery Running', 'YesNo', 'Warning')
            if ($r -eq [System.Windows.Forms.DialogResult]::No) {
                Write-Log 'FormClosing cancelled — discovery still running'
                $e.Cancel = $true; return
            }
            if ($script:discTimer -and $script:discTimer.Enabled) { $script:discTimer.Stop() }
            try { $script:discProcess.Kill($true) } catch {}
            Write-Log 'FormClosing: process tree killed'
        }
        Write-Log '=== Discovery form closed ==='
    }.GetNewClosure())

    Write-Log 'Entering Application::Run'
    [System.Windows.Forms.Application]::Run($form)
    Write-Log 'Application::Run returned'
}

Write-Log 'Calling Show-DiscoveryMenu'
try {
    Show-DiscoveryMenu
    Write-Log '=== discovery-menu.ps1 exiting normally ==='
} catch {
    Write-Log "FATAL: $($_.Exception.Message)" 'ERROR'
    Write-Log "Stack: $($_.ScriptStackTrace)" 'ERROR'
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to start M365 Discovery:`n`n$($_.Exception.Message)",
        'Launch Error', 'OK', 'Error') | Out-Null
}
