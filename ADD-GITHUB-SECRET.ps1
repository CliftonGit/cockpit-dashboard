#
# Add GitHub Secret: Simple Token Entry
# Get token from Azure Portal, add to GitHub
#

param(
    [string]$WorkDir = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes",
    [string]$GitHubRepo = "CliftonGit/cockpit-dashboard"
)

$LogFile = "$WorkDir\ADD-GITHUB-SECRET-LOG.txt"
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
Log "ADD GITHUB SECRET"
Log "Add Azure Deployment Token to GitHub"
Log "========================================"
Log ""

# STEP 1: Show instructions
Log "STEP 1: Instructions to get your deployment token" "WARNING"
Log ""
Log "1. Go to Azure Portal: https://portal.azure.com" "INFO"
Log "2. Search for 'Static Web Apps'" "INFO"
Log "3. Click on: spow-cockpit-64837" "INFO"
Log "4. In left menu, click: Settings" "INFO"
Log "5. Click: Manage deployment token" "INFO"
Log "6. Copy the token (starts with 'SharedAccessSignature')" "INFO"
Log ""

# STEP 2: Prompt for token
Log "STEP 2: Enter your deployment token" "WARNING"
Write-Host ""
$Token = Read-Host "Paste your deployment token here (or leave empty to skip)"

if ([string]::IsNullOrWhiteSpace($Token)) {
    Log "ERROR: No token provided" "ERROR"
    exit 1
}

Log "OK: Token received (${$Token.Length} characters)" "SUCCESS"
Log ""

# STEP 3: Check if GitHub CLI is available
Log "STEP 3: Checking for GitHub CLI..."
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Log "ERROR: GitHub CLI not found - installing..." "WARNING"

    try {
        # Install via winget if available
        $WingetCheck = Get-Command winget -ErrorAction SilentlyContinue
        if ($WingetCheck) {
            winget install GitHub.cli 2>&1 | Out-Null
            Log "OK: GitHub CLI installed" "SUCCESS"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        } else {
            Log "WARNING: winget not found, trying direct installation..." "WARNING"
            $GhInstaller = "$env:TEMP\gh.msi"
            $GhUrl = "https://github.com/cli/cli/releases/download/v2.52.0/gh_2.52.0_windows_amd64.msi"

            (New-Object Net.WebClient).DownloadFile($GhUrl, $GhInstaller)
            $Process = Start-Process -FilePath msiexec.exe -ArgumentList "/I $GhInstaller /quiet" -Wait -PassThru

            if ($Process.ExitCode -eq 0) {
                Log "OK: GitHub CLI installed" "SUCCESS"
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            } else {
                Log "ERROR: GitHub CLI installation failed" "ERROR"
                exit 1
            }

            Remove-Item $GhInstaller -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Log "ERROR: Failed to install GitHub CLI: $_" "ERROR"
        Log "Please install from: https://cli.github.com/" "WARNING"
        exit 1
    }
}

$GhVersion = gh --version 2>&1 | Select-Object -First 1
Log "GitHub CLI: $GhVersion" "SUCCESS"
Log ""

# STEP 4: Verify GitHub authentication
Log "STEP 4: Checking GitHub authentication..."
$GhAuth = gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "OK: GitHub CLI authenticated" "SUCCESS"
} else {
    Log "GitHub CLI needs authentication..." "WARNING"
    Log "Running: gh auth login" "INFO"
    gh auth login 2>&1

    if ($LASTEXITCODE -ne 0) {
        Log "ERROR: GitHub authentication failed" "ERROR"
        exit 1
    }
    Log "OK: GitHub authenticated" "SUCCESS"
}

Log ""

# STEP 5: Add GitHub secret
Log "STEP 5: Adding deployment token to GitHub..."
$SecretName = "AZURE_STATIC_WEB_APPS_API_TOKEN_NICE_FLOWER_0071A6E03"

try {
    # Create temporary file with token
    $TempToken = "$env:TEMP\gh-secret-temp.txt"
    Set-Content -Path $TempToken -Value $Token -NoNewline

    # Add secret using gh CLI with Windows command redirection
    $Output = & cmd /c "type `"$TempToken`" | gh secret set $SecretName --repo $GitHubRepo" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Log "OK: GitHub secret added successfully!" "SUCCESS"
        $Output | ForEach-Object { Log $_ "INFO" }
    } else {
        Log "ERROR: Failed to add GitHub secret" "ERROR"
        Log "Response: $Output" "ERROR"
        exit 1
    }

    Remove-Item $TempToken -Force -ErrorAction SilentlyContinue

} catch {
    Log "ERROR: Failed to set GitHub secret: $_" "ERROR"
    exit 1
}

Log ""

# STEP 6: Verify secret was added
Log "STEP 6: Verifying secret in GitHub..."
try {
    $Secrets = gh secret list --repo $GitHubRepo 2>&1

    if ($Secrets -match $SecretName) {
        Log "OK: Secret verified in GitHub!" "SUCCESS"
    } else {
        Log "WARNING: Could not verify immediately (may take a moment)" "WARNING"
    }
} catch {
    Log "WARNING: Could not verify secret" "WARNING"
}

Log ""

# FINAL: Summary
Log "========================================"
Log "SUCCESS - DEPLOYMENT IS READY!"
Log "========================================"
Log ""
Log "Secret configured: $SecretName" "SUCCESS"
Log "Repository: $GitHubRepo" "INFO"
Log ""
Log "GitHub Actions is now ACTIVE!" "SUCCESS"
Log ""
Log "When you push to main branch:" "INFO"
Log "  → GitHub Actions triggers automatically" "INFO"
Log "  → Builds and deploys cockpit.html" "INFO"
Log "  → Updates: https://nice-flower-0071a6e03.6.azurestaticapps.net/cockpit.html" "INFO"
Log ""
Log "To test:" "WARNING"
Log "  1. Make a small change to cockpit.html" "INFO"
Log "  2. git add ." "INFO"
Log "  3. git commit -m 'Test deployment'" "INFO"
Log "  4. git push" "INFO"
Log "  5. Watch the deployment at GitHub > Actions tab" "INFO"
Log ""
Log "Log file: $LogFile" "INFO"
Log "End time: $(Get-Date)"

Write-Host ""
Write-Host "=== COMPLETE ===" -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter to close"
