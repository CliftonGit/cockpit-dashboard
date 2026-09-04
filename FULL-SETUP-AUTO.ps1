#
# Full Automated Setup: Install Git + Setup GitHub + Commit
# Everything logged, completely automatic
#

param(
    [string]$WorkDir = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes"
)

$LogFile = "$WorkDir\FULL-SETUP-LOG.txt"
"" | Set-Content -Path $LogFile

function Log {
    param([string]$Message, [string]$Type = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Type] $Message"
    Add-Content -Path $LogFile -Value $LogMessage

    $Color = switch($Type) {
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        default { "White" }
    }
    Write-Host $LogMessage -ForegroundColor $Color
}

Log "========================================"
Log "FULL AUTOMATED SETUP"
Log "Git Installation + GitHub Setup + Initial Commit"
Log "========================================"
Log ""

# STEP 1: Check and install Git
Log "STEP 1: Checking Git installation..."

if (Get-Command git -ErrorAction SilentlyContinue) {
    $GitVersion = git --version
    Log "OK: Git already installed - $GitVersion" "SUCCESS"
} else {
    Log "Git not found - Installing..." "WARNING"
    Log "Downloading Git installer..." "INFO"

    try {
        $GitInstaller = "$env:TEMP\GitInstaller.exe"
        $GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/Git-2.46.0-64-bit.exe"

        # Download
        (New-Object Net.WebClient).DownloadFile($GitUrl, $GitInstaller)
        Log "OK: Downloaded Git installer" "SUCCESS"

        # Install silently
        Log "Installing Git silently..." "INFO"
        $Process = Start-Process -FilePath $GitInstaller -ArgumentList '/VERYSILENT /NORESTART' -Wait -PassThru

        if ($Process.ExitCode -eq 0) {
            Log "OK: Git installed successfully" "SUCCESS"

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        } else {
            Log "ERROR: Git installation failed with code $($Process.ExitCode)" "ERROR"
            exit 1
        }

        # Cleanup
        Remove-Item $GitInstaller -Force -ErrorAction SilentlyContinue

    } catch {
        Log "ERROR: Could not install Git: $_" "ERROR"
        Log "Please install manually from: https://git-scm.com/download/win" "WARNING"
        exit 1
    }
}

Log ""

# STEP 2: Verify Git installation
Log "STEP 2: Verifying Git..."
try {
    $GitTest = git --version 2>&1
    Log "Git version: $GitTest" "SUCCESS"
} catch {
    Log "ERROR: Git verification failed" "ERROR"
    exit 1
}

Log ""

# STEP 3: Initialize Git repository
Log "STEP 3: Setting up Git repository..."
Push-Location $WorkDir

$IsRepo = Test-Path "$WorkDir\.git"
if ($IsRepo) {
    Log "Git repository already exists" "INFO"
} else {
    git init 2>&1 | ForEach-Object { Log $_ }
    Log "OK: Repository initialized" "SUCCESS"
}

Log ""

# STEP 4: Configure Git
Log "STEP 4: Configuring Git..."
git config user.email "clifton.dobbelsteyn@boels.nl" 2>&1 | Out-Null
git config user.name "Clifton Dobbelsteyn" 2>&1 | Out-Null
Log "OK: Git configured" "SUCCESS"

Log ""

# STEP 5: Create GitHub workflow directory
Log "STEP 5: Creating GitHub Actions workflow..."
$WorkflowDir = "$WorkDir\.github\workflows"
New-Item -ItemType Directory -Path $WorkflowDir -Force | Out-Null

$WorkflowContent = @'
name: Deploy Cockpit to Azure Static Web App

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build_and_deploy_job:
    runs-on: ubuntu-latest
    name: Build and Deploy Job
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: true

      - name: Build App
        run: |
          echo "Building static app..."
          ls -la

      - name: Deploy to Static Web App
        id: builddeploy
        uses: Azure/static-web-apps-deploy@v1
        with:
          azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN_NICE_FLOWER_0071A6E03 }}
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          action: "upload"
          app_location: "."
          api_location: ""
          output_location: ""
'@

Set-Content -Path "$WorkflowDir\azure-static-web-apps-deploy.yml" -Value $WorkflowContent
Log "OK: Workflow file created" "SUCCESS"

Log ""

# STEP 6: Create .gitignore
Log "STEP 6: Creating .gitignore..."
$GitIgnoreContent = @'
# Logs
*.log
DEPLOYMENT-*.txt
*-LOG.txt

# Temporary files
.tmp
~*

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
'@

Set-Content -Path "$WorkDir\.gitignore" -Value $GitIgnoreContent
Log "OK: .gitignore created" "SUCCESS"

Log ""

# STEP 7: Create deployment info
Log "STEP 7: Creating deployment info..."
$DeploymentInfo = @"
# Cockpit Dashboard - Azure Static Web App

## App Details
- Name: spow-cockpit-64837
- URL: https://nice-flower-0071a6e03.6.azurestaticapps.net
- File: cockpit.html
- Auth: Entra ID

## Deployment
Push to 'main' branch → GitHub Actions → Auto deploy

## Quick Links
- Azure Portal: https://portal.azure.com
- GitHub: https://github.com
- Static Web App: https://portal.azure.com/#@boels.nl/resource/subscriptions/ed8c9803-e8e9-4728-b56e-984cd2327a06/resourceGroups/rg-boels-d-spow/providers/Microsoft.Web/staticSites/spow-cockpit-64837

Generated: $(Get-Date)
"@

Set-Content -Path "$WorkDir\DEPLOYMENT-INFO.md" -Value $DeploymentInfo
Log "OK: Deployment info created" "SUCCESS"

Log ""

# STEP 8: Stage files
Log "STEP 8: Staging files for commit..."
git add . 2>&1 | Out-Null

$Status = git status --short 2>&1
Log "Files staged:" "INFO"
$Status | ForEach-Object { Log "  $_" "INFO" }

Log ""

# STEP 9: Create initial commit
Log "STEP 9: Creating initial commit..."
git commit -m "Initial commit: Add Cockpit dashboard with GitHub Actions workflow

- Added cockpit.html with Entra ID authentication
- Added GitHub Actions workflow for Azure Static Web App deployment
- Added .gitignore and deployment documentation

Auto-generated by deployment automation script." 2>&1 | ForEach-Object { Log $_ }

if ($LASTEXITCODE -eq 0) {
    Log "OK: Initial commit created successfully" "SUCCESS"
} else {
    Log "WARNING: Commit may have had issues, but continuing..." "WARNING"
}

Log ""

# STEP 10: Show repository status
Log "STEP 10: Repository status..."
$FinalStatus = git log --oneline -5 2>&1
Log "Commit history:" "INFO"
$FinalStatus | ForEach-Object { Log "  $_" "INFO" }

Log ""

# FINAL: Instructions
Log "========================================"
Log "SETUP COMPLETE - REPOSITORY READY"
Log "========================================"
Log ""
Log "YOUR LOCAL REPOSITORY IS READY:" "SUCCESS"
Log ""
Log "NEXT: Push to GitHub" "WARNING"
Log ""
Log "1. Create a GitHub repository:" "INFO"
Log "   - Go to: https://github.com/new"
Log "   - Name: cockpit-dashboard"
Log "   - Description: Cockpit Dashboard for Azure Static Web App"
Log "   - Do NOT check 'Initialize with README'"
Log "   - Click 'Create repository'"
Log ""
Log "2. After creating the repo, copy and run these commands:" "INFO"
Log "   git remote add origin https://github.com/YOUR_USERNAME/cockpit-dashboard.git"
Log "   git branch -M main"
Log "   git push -u origin main"
Log ""
Log "3. Then configure Azure deployment token:" "INFO"
Log "   - Go to Azure Portal"
Log "   - Static Web App > Manage deployment token"
Log "   - Copy the token"
Log "   - Go to GitHub repo > Settings > Secrets and variables > Actions"
Log "   - Create new secret:"
Log "     Name: AZURE_STATIC_WEB_APPS_API_TOKEN_NICE_FLOWER_0071A6E03"
Log "     Value: [paste token from Azure]"
Log ""
Log "4. Done! GitHub Actions will now:" "SUCCESS"
Log "   - Deploy automatically on every push"
Log "   - Publish to: https://nice-flower-0071a6e03.6.azurestaticapps.net/cockpit.html"
Log ""
Log "Repository location: $WorkDir" "INFO"
Log "Log file: $LogFile" "INFO"
Log ""
Log "End time: $(Get-Date)"

Pop-Location

Write-Host ""
Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
Write-Host "Check log for commands to run next"
Write-Host ""

Read-Host "Press Enter to close"
