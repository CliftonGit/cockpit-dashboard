#
# Setup GitHub Repository for Azure Static Web App Deployment
# Completely automated with logging
#

param(
    [string]$WorkDir = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes",
    [string]$GitHubUsername = "cliftondobbelsteyn"  # Will be replaced with actual username
)

$LogFile = "$WorkDir\GITHUB-SETUP-LOG.txt"
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
Log "GitHub Repository Setup for Azure Static Web App"
Log "========================================"
Log ""

# STEP 1: Check if git is installed
Log "STEP 1: Checking Git installation..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Log "ERROR: Git is not installed" "ERROR"
    Log "Please install Git from: https://git-scm.com/download/win" "WARNING"
    exit 1
}

$GitVersion = git --version
Log "OK: Git installed - $GitVersion" "SUCCESS"
Log ""

# STEP 2: Check if already a git repo
Log "STEP 2: Checking for existing Git repository..."
Push-Location $WorkDir
$IsRepo = Test-Path "$WorkDir\.git"

if ($IsRepo) {
    Log "WARNING: Git repository already exists" "WARNING"
    Log "Will update existing repository" "INFO"
} else {
    Log "Initializing new Git repository..."
    git init 2>&1 | ForEach-Object { Log $_ }
    Log "OK: Repository initialized" "SUCCESS"
}
Log ""

# STEP 3: Setup git config
Log "STEP 3: Configuring Git..."
git config user.email "clifton.dobbelsteyn@boels.nl" 2>&1 | Out-Null
git config user.name "Clifton Dobbelsteyn" 2>&1 | Out-Null
Log "OK: Git configured with user details" "SUCCESS"
Log ""

# STEP 4: Create workflows directory
Log "STEP 4: Creating GitHub Actions workflow directory..."
$WorkflowDir = "$WorkDir\.github\workflows"
if (-not (Test-Path $WorkflowDir)) {
    New-Item -ItemType Directory -Path $WorkflowDir -Force | Out-Null
    Log "OK: Directory created - $WorkflowDir" "SUCCESS"
} else {
    Log "OK: Directory already exists" "SUCCESS"
}
Log ""

# STEP 5: Copy workflow file
Log "STEP 5: Setting up GitHub Actions workflow..."
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

$WorkflowFile = "$WorkflowDir\azure-static-web-apps-deploy.yml"
Set-Content -Path $WorkflowFile -Value $WorkflowContent
Log "OK: Workflow file created - $WorkflowFile" "SUCCESS"
Log ""

# STEP 6: Create .gitignore
Log "STEP 6: Creating .gitignore..."
$GitIgnoreContent = @'
# Logs
*.log
DEPLOYMENT-*.txt
GITHUB-SETUP-LOG.txt

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

# STEP 7: Create deployment info file
Log "STEP 7: Creating deployment information file..."
$DeploymentInfo = @"
# Azure Static Web App - Cockpit Dashboard

## Deployment Information
- App Name: spow-cockpit-64837
- Hostname: nice-flower-0071a6e03.6.azurestaticapps.net
- Subscription: ed8c9803-e8e9-4728-b56e-984cd2327a06
- Resource Group: rg-boels-d-spow

## Files
- cockpit.html: Main dashboard file with Entra ID authentication

## Deployment Method
GitHub Actions automatically deploys when you push to the 'main' branch.

## To Deploy
1. Push changes to GitHub main branch
2. GitHub Actions workflow runs automatically
3. Site updates at: https://nice-flower-0071a6e03.6.azurestaticapps.net/cockpit.html

Generated: $(Get-Date)
"@

Set-Content -Path "$WorkDir\DEPLOYMENT-INFO.md" -Value $DeploymentInfo
Log "OK: Deployment info file created" "SUCCESS"
Log ""

# STEP 8: Stage files for commit
Log "STEP 8: Preparing files for commit..."
git add cockpit.html 2>&1 | Out-Null
git add .github/ 2>&1 | Out-Null
git add .gitignore 2>&1 | Out-Null
git add DEPLOYMENT-INFO.md 2>&1 | Out-Null

$Status = git status --short 2>&1
Log "Staged files:" "INFO"
$Status | ForEach-Object { Log "  $_" }
Log ""

# STEP 9: Create initial commit
Log "STEP 9: Creating initial commit..."
git commit -m "Initial commit: Add Cockpit dashboard with GitHub Actions workflow" 2>&1 | ForEach-Object { Log $_ }
Log "OK: Initial commit created" "SUCCESS"
Log ""

# STEP 10: Show next steps
Log "========================================"
Log "SETUP COMPLETE"
Log "========================================"
Log ""
Log "NEXT STEPS:" "WARNING"
Log "1. Create a new repository on GitHub:"
Log "   - Go to: https://github.com/new"
Log "   - Repository name: cockpit-dashboard"
Log "   - Do NOT initialize with README, .gitignore, or license"
Log "   - Click 'Create repository'"
Log ""
Log "2. After creating the repository, run:"
Log "   git remote add origin https://github.com/YOUR_USERNAME/cockpit-dashboard.git"
Log "   git branch -M main"
Log "   git push -u origin main"
Log ""
Log "3. After push, configure Azure Static Web App:"
Log "   - Go to your Static Web App in Azure Portal"
Log "   - Select 'Deployment' -> 'Manage deployment token'"
Log "   - Copy the token"
Log "   - Create GitHub secret in your repo (Settings -> Secrets)"
Log "   - Name: AZURE_STATIC_WEB_APPS_API_TOKEN_NICE_FLOWER_0071A6E03"
Log "   - Value: [paste the token]"
Log ""
Log "4. After GitHub secret is configured:"
Log "   - Push any change to trigger deployment"
Log "   - GitHub Actions automatically builds and deploys"
Log ""
Log "Current Git status:"
git status 2>&1 | ForEach-Object { Log $_ }
Log ""
Log "Log file: $LogFile"
Log "End time: $(Get-Date)"

Pop-Location
Read-Host "Press Enter to close"
