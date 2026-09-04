#
# Push Local Repository to GitHub
# Completely automated with logging
#

param(
    [string]$WorkDir = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes",
    [string]$GitHubUrl = ""  # Will be provided interactively
)

$LogFile = "$WorkDir\PUSH-TO-GITHUB-LOG.txt"
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
Log "PUSH TO GITHUB"
Log "========================================"
Log ""

# Get GitHub URL if not provided
if (-not $GitHubUrl) {
    Write-Host ""
    Write-Host "Enter your GitHub repository URL:" -ForegroundColor Cyan
    Write-Host "Example: https://github.com/CliftonGit/cockpit-dashboard.git" -ForegroundColor Yellow
    Write-Host ""
    $GitHubUrl = Read-Host "GitHub URL"

    if (-not $GitHubUrl) {
        Log "ERROR: No GitHub URL provided" "ERROR"
        exit 1
    }
}

Log "GitHub URL: $GitHubUrl" "INFO"
Log ""

# Change to work directory
Log "STEP 1: Changing to work directory..."
Push-Location $WorkDir

Log "Location: $WorkDir" "SUCCESS"
Log ""

# Verify git is available
Log "STEP 2: Verifying Git..."
try {
    $GitVersion = git --version 2>&1
    Log "Git: $GitVersion" "SUCCESS"
} catch {
    Log "ERROR: Git not found" "ERROR"
    exit 1
}
Log ""

# Check current repo status
Log "STEP 3: Checking repository status..."
$Status = git status 2>&1
Log "Current branch: $(git branch --show-current 2>&1)" "INFO"
$Commits = git log --oneline -1 2>&1
Log "Latest commit: $Commits" "INFO"
Log ""

# Add remote
Log "STEP 4: Adding GitHub remote..."
git remote remove origin 2>$null  # Remove if exists
$AddRemote = git remote add origin $GitHubUrl 2>&1

if ($LASTEXITCODE -eq 0) {
    Log "OK: Remote added" "SUCCESS"
} else {
    Log "ERROR: Could not add remote - $AddRemote" "ERROR"
    exit 1
}
Log ""

# Rename branch to main
Log "STEP 5: Renaming branch to main..."
$RenameBranch = git branch -M main 2>&1

if ($LASTEXITCODE -eq 0) {
    Log "OK: Branch renamed to main" "SUCCESS"
} else {
    Log "WARNING: Branch rename - $RenameBranch" "WARNING"
}
Log ""

# Push to GitHub
Log "STEP 6: Pushing to GitHub..."
Log "    This may take a moment..." "INFO"

$Push = git push -u origin main 2>&1

if ($LASTEXITCODE -eq 0) {
    Log "OK: Push successful!" "SUCCESS"
    Log ""
    $Push | ForEach-Object { Log $_ "INFO" }
} else {
    Log "ERROR: Push failed" "ERROR"
    Log ""
    $Push | ForEach-Object { Log $_ "ERROR" }
    Log ""
    Log "TROUBLESHOOTING:" "WARNING"
    Log "  - Ensure you're logged into GitHub on this machine"
    Log "  - Ensure the GitHub URL is correct"
    Log "  - You may need to authenticate with GitHub"
    Log ""
    exit 1
}
Log ""

# Verify push
Log "STEP 7: Verifying push..."
$Remote = git remote -v 2>&1
Log "Remote configured:" "INFO"
$Remote | ForEach-Object { Log "  $_" "INFO" }
Log ""

# Show what was pushed
Log "STEP 8: Repository information..."
$Log = git log --oneline -3 2>&1
Log "Recent commits:" "INFO"
$Log | ForEach-Object { Log "  $_" "INFO" }
Log ""

Log "========================================"
Log "PUSH COMPLETE!"
Log "========================================"
Log ""
Log "Repository is now on GitHub:" "SUCCESS"
Log "  URL: $GitHubUrl" "INFO"
Log "  Branch: main" "INFO"
Log ""
Log "NEXT STEP: Configure Azure Deployment Token" "WARNING"
Log ""
Log "1. Go to Azure Portal"
Log "2. Find your Static Web App: spow-cockpit-64837"
Log "3. Settings > Manage deployment token"
Log "4. Copy the token (long string starting with 'SharedAccessSignature')"
Log ""
Log "5. Go to your GitHub repo:"
Log "   Settings > Secrets and variables > Actions > New repository secret"
Log ""
Log "6. Create the secret:"
Log "   Name: AZURE_STATIC_WEB_APPS_API_TOKEN_NICE_FLOWER_0071A6E03"
Log "   Value: [paste the token from Azure]"
Log ""
Log "7. Click 'Add secret'"
Log ""
Log "Then: GitHub Actions will automatically deploy on any push!" "SUCCESS"
Log ""
Log "Deployment URL:"
Log "https://nice-flower-0071a6e03.6.azurestaticapps.net/cockpit.html" "CYAN"
Log ""
Log "Log file: $LogFile" "INFO"
Log "End time: $(Get-Date)"

Pop-Location

Write-Host ""
Write-Host "=== PUSH COMPLETE ===" -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter to close"
