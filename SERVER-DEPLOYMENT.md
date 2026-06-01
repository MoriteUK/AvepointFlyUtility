# Server Deployment Guide

This guide explains how to deploy the VG Migration Tools to your server.

## Quick Deployment Steps

### 1. Copy Files to Server

Copy the entire `VGMigrations` folder to your server:
```
C:\Scripts\VGMigrations\
```

### 2. Set Up Fly API Configuration

The Fly API configuration needs to be placed in the server's AppData folder.

**Option A: Copy the config file (if same user account)**
```powershell
# On your LOCAL machine, the config is here:
C:\Users\[YourUsername]\AppData\Roaming\FlyMigration\config.json

# Copy it to the SERVER at:
C:\Users\[ServerUsername]\AppData\Roaming\FlyMigration\config.json
```

**Option B: Use the included fly-config.json**
```powershell
# On the server, run:
$destFolder = "$env:APPDATA\FlyMigration"
New-Item -ItemType Directory -Path $destFolder -Force
Copy-Item "C:\Scripts\VGMigrations\fly-config.json" -Destination "$destFolder\config.json"
```

**Option C: Enter credentials via Settings (Recommended if encryption doesn't work)**
1. Launch the toolkit: `.\main-menu.ps1`
2. Click the ⚙ Settings icon
3. Go to **Config** tab
4. Enter:
   - **Fly API URL**: `https://graph.avepointonlineservices.com/fly`
   - **Client ID**: `e982b3fe-ebb8-4926-aa2e-03065c6a8407`
   - **Client Secret**: (your secret - get from original machine if needed)
5. Click **Test Connection** to verify
6. Close Settings (auto-saves)

### 3. Important Files for Server

These files should be transferred from your working installation:

**Required Configuration:**
- `fly-config.json` → Copy to `%APPDATA%\FlyMigration\config.json`
- `domains.json` - Domain to VBU ID mappings
- `workloads.json` - Workload configuration
- `tenant-sites.json` - SharePoint site data (if using)

**Optional (can be recreated):**
- `shared-config.json` - Customer prefixes, portal URL, secret expiry

### 4. Install Prerequisites

**On the server, you need:**

1. **PowerShell 7+**
   ```powershell
   # Check version
   $PSVersionTable.PSVersion
   
   # Install if needed
   winget install Microsoft.PowerShell
   ```

2. **Microsoft Graph PowerShell Modules**
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   ```

3. **Exchange Online Management** (for Hide from Address Book)
   ```powershell
   Install-Module ExchangeOnlineManagement -Scope CurrentUser
   ```

4. **Active Directory Module** (for On-Premise UPN updates)
   - Already installed on Domain Controllers
   - Or install RSAT tools on regular servers

5. **Node.js and Playwright** (for AvePoint Fly automation)
   ```powershell
   # Run the setup script once
   .\Setup.ps1
   ```

### 5. Launch the Toolkit

**Option 1: Double-click**
```
MigrationTools.exe
```

**Option 2: PowerShell**
```powershell
.\main-menu.ps1
```

### 6. Verify Auto-Update Works

The toolkit checks for updates from GitHub automatically:
- Repository: `MoriteUK/AvepointFlyUtility`
- Yellow banner appears when updates are available
- Click "Install Update" to get latest version

## Configuration File Locations

| File | Purpose | Location |
|------|---------|----------|
| `config.json` | Fly API credentials | `%APPDATA%\FlyMigration\config.json` |
| `domains.json` | Domain mappings | `VGMigrations\domains.json` |
| `workloads.json` | Workload settings | `VGMigrations\workloads.json` |
| `shared-config.json` | Customer info | `VGMigrations\shared-config.json` |
| `version.json` | Current version | `VGMigrations\version.json` |

## Troubleshooting

### "Script not found" errors
- Ensure all .ps1 files are in the same folder
- Run: `.\Check-Updates.ps1 -Force` to download missing files

### Fly API connection fails
- Verify credentials in Settings > Config
- Click "Test Connection" button
- Check the secret hasn't expired

### Module errors
- Install required PowerShell modules (see Prerequisites)
- Restart PowerShell after installing modules

### Auto-update not working
1. Check internet connectivity to GitHub
2. Verify repository is accessible: https://github.com/MoriteUK/AvepointFlyUtility
3. Run manually: `.\Check-Updates.ps1 -Force`

## Files Excluded from Git (Created Locally)

These files/folders are created during use and should **not** be transferred:
- `logs\` - Log files
- `reports\` - Migration reports  
- `backup-*\` - Update backups
- `auth\storageState.json` - Playwright auth

## Support

Current Version: **2.1.3**  
Repository: https://github.com/MoriteUK/AvepointFlyUtility

For issues, check:
1. Log files in `logs\` folder
2. GitHub repository for latest updates
3. Settings > Config > Check for Updates
