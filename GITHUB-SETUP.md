# GitHub Auto-Update Setup Guide

This guide will help you set up automatic updates from GitHub for the VG Migration Tools (AvePoint Fly edition).

## Prerequisites

- GitHub account
- Git installed on your computer
- PowerShell 7.0 or higher

## Step 1: Create GitHub Repository

1. **Go to GitHub** and sign in to your account
2. **Click the "+" icon** in the top right corner and select "New repository"
3. **Repository settings:**
   - **Repository name**: `VGMigrations-AvePoint` (or your preferred name)
   - **Description**: `VG Migration Tools for AvePoint Fly`
   - **Visibility**: 
     - **Private** (recommended for internal tools)
     - **Public** (if you want to share publicly)
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
4. **Click "Create repository"**

## Step 2: Initialize Local Repository

Open PowerShell in the VGMigrations folder:

```powershell
cd "c:\Temp\Scripts\VGMigrations"

# Initialize git (if not already done)
git init

# Add all files
git add .

# Create first commit
git commit -m "Initial commit - VG Migration Tools v2.0.0"

# Add GitHub as remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/VGMigrations-AvePoint.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 3: Configure Auto-Update

Edit `Check-Updates.ps1` and update the GitHub repository URL:

```powershell
# Line 20 - Update with your repository
param(
    [string]$GitHubRepo = "YOUR_USERNAME/VGMigrations-AvePoint",
    ...
)
```

**Example:**
```powershell
[string]$GitHubRepo = "andy-white/VGMigrations-AvePoint",
```

## Step 4: Test Auto-Update

Test the update checker manually:

```powershell
# Check for updates (dry run)
.\Check-Updates.ps1

# Force check even if recently checked
.\Check-Updates.ps1 -Force

# Silent mode (auto-install)
.\Check-Updates.ps1 -Silent
```

## How Auto-Update Works

### Automatic Checks

The main menu (`main-menu.ps1`) automatically checks for updates:
- **When**: Every time you launch the tool
- **Frequency**: Maximum once per 24 hours
- **Mode**: Silent background check (doesn't block startup)

### Update Process

1. **Check**: Compares local `version.json` with GitHub version
2. **Download**: If update available, downloads latest ZIP from GitHub
3. **Backup**: Backs up your configuration files
4. **Install**: Copies new files (preserving your settings)
5. **Restore**: Restores your configuration files

### Protected Files

These files are **NEVER** overwritten during updates:
- `domains.json` - Your domain configurations
- `workloads.json` - Your workload mappings
- `tenant-sites.json` - Your tenant sites
- `shared-config.json` - Shared settings
- `logs/` - All log files
- `reports/` - All reports
- `auth/` - Authentication tokens

## Publishing Updates

When you make changes and want to push updates:

```powershell
cd "c:\Temp\Scripts\VGMigrations"

# 1. Update version.json with new version number
# Edit version.json and increment the version

# 2. Check what changed
git status

# 3. Add your changes
git add .

# 4. Commit with descriptive message
git commit -m "Add: New feature for bulk user updates"

# 5. Push to GitHub
git push
```

### Version Numbering

Follow semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes (e.g., 1.0.0 → 2.0.0)
- **MINOR**: New features (e.g., 2.0.0 → 2.1.0)
- **PATCH**: Bug fixes (e.g., 2.1.0 → 2.1.1)

**Example version.json update:**

```json
{
  "version": "2.1.0",
  "releaseDate": "2026-06-01",
  "changelog": [
    {
      "version": "2.1.0",
      "date": "2026-06-01",
      "changes": [
        "Added bulk user export feature",
        "Fixed sorting issue in Update-UPN",
        "Improved error messages"
      ]
    },
    ...
  ]
}
```

## Troubleshooting

### Update Check Not Working

1. **Check internet connection**
2. **Verify GitHub repository is accessible:**
   ```powershell
   # Test URL (replace with your repo)
   Invoke-RestMethod -Uri "https://raw.githubusercontent.com/YOUR_USERNAME/VGMigrations-AvePoint/main/version.json"
   ```
3. **Check logs:**
   ```powershell
   Get-Content "c:\Temp\Scripts\VGMigrations\logs\updates-*.log" | Select-Object -Last 50
   ```

### Authentication Issues (Private Repo)

For private repositories, you'll need a Personal Access Token:

1. **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. **Generate new token** with `repo` scope
3. **Update Check-Updates.ps1:**

```powershell
# Add authentication header
$Headers = @{
    Authorization = "Bearer YOUR_GITHUB_TOKEN"
}

Invoke-RestMethod -Uri $GitHubVersionUrl -Headers $Headers
```

### Force Update

If auto-update fails, manually update:

```powershell
# Download latest from GitHub
Invoke-WebRequest -Uri "https://github.com/YOUR_USERNAME/VGMigrations-AvePoint/archive/refs/heads/main.zip" -OutFile "update.zip"

# Extract and copy files (preserving your configs)
```

## Best Practices

### Before Pushing Updates

1. ✅ **Test locally** - Ensure scripts work
2. ✅ **Update version.json** - Increment version number
3. ✅ **Update changelog** - Document changes
4. ✅ **Review .gitignore** - Don't commit logs/configs
5. ✅ **Write clear commit message** - Describe what changed

### Commit Message Format

```
Type: Brief description

Detailed explanation if needed

- Bullet points for specific changes
- Reference issue numbers if applicable
```

**Types:**
- `Add:` - New feature
- `Fix:` - Bug fix
- `Update:` - Modify existing feature
- `Remove:` - Delete feature/code
- `Docs:` - Documentation only

**Examples:**
```
Add: Bulk UPN update with checkbox selection

- Added checkboxes to device list
- Users can select/deselect individual accounts
- Improved error handling for on-prem synced users
```

## Security Considerations

### Don't Commit Sensitive Data

Ensure `.gitignore` excludes:
- ✅ API keys and secrets
- ✅ Authentication tokens
- ✅ User-specific configurations
- ✅ Customer data
- ✅ Log files with sensitive information

### Review Before Push

```powershell
# Always review what you're about to commit
git diff

# Check staged files
git status

# If you accidentally staged sensitive files:
git reset HEAD <file>
```

## Advanced: Automatic Push on Changes

To automatically push changes to GitHub when you modify scripts:

```powershell
# Create a git hook (run once)
$hookPath = "c:\Temp\Scripts\VGMigrations\.git\hooks\post-commit"
$hookContent = @'
#!/bin/sh
git push origin main
'@
Set-Content -Path $hookPath -Value $hookContent -Encoding ASCII
```

**Warning**: This pushes every commit immediately. Only use if you're the sole developer.

## Support

For issues or questions:
- Check logs: `c:\Temp\Scripts\VGMigrations\logs\updates-*.log`
- Review GitHub repository settings
- Verify version.json format
- Test network connectivity to GitHub

---

**Repository**: https://github.com/YOUR_USERNAME/VGMigrations-AvePoint  
**Last Updated**: 2026-05-31  
**Version**: 2.0.0
