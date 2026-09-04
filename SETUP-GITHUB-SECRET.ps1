#
# Setup GitHub Secret: Add Azure Deployment Token
# Completely automated - gets token from Azure and adds to GitHub
#

param(
    [string]$WorkDir = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes",
    [string]$GitHubRepo = "CliftonGit/cockpit-dashboard"
)

$LogFile = "$WorkDir\SETUP-GITHUB-SECRET-LOG.txt"
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
Log "SETUP GITHUB SECRET"
Log "Add Azure Deployment Token to GitHub"
Log "========================================"
Log ""

# STEP 1: Check if Azure CLI is available
Log "STEP 1: Checking for Azure CLI..."
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Log "ERROR: Azure CLI not found" "ERROR"
    Log "Installing Azure CLI..." "WARNING"

    try {
        # Download Azure CLI installer
        $AzInstaller = "$env:TEMP\AzureCLI.msi"
        $AzUrl = "https://aka.ms/installazurecliwindows"

        Log "Downloading Azure CLI..." "INFO"
        (New-Object Net.WebClient).DownloadFile($AzUrl, $AzInstaller)
        Log "OK: Downloaded Azure CLI" "SUCCESS"

        # Install silently
        Log "Installing Azure CLI..." "INFO"
        $Process = Start-Process -FilePath msiexec.exe -ArgumentList "/I $AzInstaller /quiet" -Wait -PassThru

        if ($Process.ExitCode -eq 0) {
            Log "OK: Azure CLI installed" "SUCCESS"
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        } else {
            Log "WARNING: Azure CLI installation may have had issues, continuing..." "WARNING"
        }

        Remove-Item $AzInstaller -Force -ErrorAction SilentlyContinue
    } catch {
        Log "WARNING: Could not install Azure CLI automatically" "WARNING"
        Log "You may need to install from: https://aka.ms/installazurecliwindows" "INFO"
    }
}

$AzVersion = az --version 2>&1 | Select-Object -First 1
Log "Azure CLI: $AzVersion" "SUCCESS"
Log ""

# STEP 2: Get Azure subscription
Log "STEP 2: Setting up Azure session..."
try {
    # Check if already logged in
    $Account = az account show 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log "OK: Already logged into Azure" "SUCCESS"
    } else {
        Log "Logging into Azure..." "WARNING"
        az login 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Log "OK: Logged into Azure" "SUCCESS"
        } else {
            Log "ERROR: Azure login failed" "ERROR"
            exit 1
        }
    }
} catch {
    Log "ERROR: Azure session setup failed" "ERROR"
    exit 1
}

Log ""

# STEP 3: Get Static Web App details
Log "STEP 3: Getting Static Web App details..."
try {
    $StaticApp = az staticwebapp show --name spow-cockpit-64837 --resource-group rg-boels-d-spow 2>&1

    if ($LASTEXITCODE -eq 0) {
        Log "OK: Found Static Web App" "SUCCESS"
    } else {
        Log "ERROR: Could not find Static Web App" "ERROR"
        exit 1
    }
} catch {
    Log "ERROR: Failed to get Static Web App info: $_" "ERROR"
    exit 1
}

Log ""

# STEP 4: Get deployment token
Log "STEP 4: Getting deployment token..."
try {
    $Token = az staticwebapp secrets list --name spow-cockpit-64837 --resource-group rg-boels-d-spow --query 'properties.apiToken' -o tsv 2>&1

    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($Token)) {
        Log "OK: Retrieved deployment token" "SUCCESS"
        Log "Token starts with: $(($Token.Substring(0, 20)))" "INFO"
    } else {
        Log "ERROR: Could not retrieve deployment token" "ERROR"
        Log "Response: $Token" "ERROR"
        exit 1
    }
} catch {
    Log "ERROR: Failed to get token: $_" "ERROR"
    exit 1
}

Log ""

# STEP 5: Check if GitHub CLI is available
Log "STEP 5: Checking for GitHub CLI..."
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

# STEP 6: Verify GitHub authentication
Log "STEP 6: Checking GitHub authentication..."
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

# STEP 7: Add GitHub secret
Log "STEP 7: Adding deployment token to GitHub..."
$SecretName = "AZURE_STATIC_WEB_APPS_API_TOKEN_NICE_FLOWER_0071A6E03"

try {
    # Create temporary file with token value
    $TempToken = "$env:TEMP\gh-secret.txt"
    Set-Content -Path $TempToken -Value $Token -NoNewline

    # Add secret using gh CLI with file input
    $Output = & cmd /c "type `"$TempToken`" | gh secret set $SecretName --repo $GitHubRepo" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Log "OK: GitHub secret added successfully" "SUCCESS"
        $Output | ForEach-Object { Log $_ "INFO" }
    } else {
        Log "ERROR: Failed to add GitHub secret" "ERROR"
        $Output | ForEach-Object { Log $_ "ERROR" }
        exit 1
    }

    Remove-Item $TempToken -Force -ErrorAction SilentlyContinue

} catch {
    Log "ERROR: Failed to set GitHub secret: $_" "ERROR"
    exit 1
}

Log ""

# STEP 8: Verify secret was added
Log "STEP 8: Verifying secret..."
try {
    $Secrets = gh secret list --repo $GitHubRepo 2>&1

    if ($Secrets -match $SecretName) {
        Log "OK: Secret verified in GitHub" "SUCCESS"
        $Secrets | ForEach-Object { Log $_ "INFO" }
    } else {
        Log "WARNING: Could not verify secret immediately" "WARNING"
    }
} catch {
    Log "WARNING: Could not verify secret: $_" "WARNING"
}

Log ""

# FINAL: Summary
Log "========================================"
Log "GITHUB SECRET SETUP COMPLETE!"
Log "========================================"
Log ""
Log "Secret Name: $SecretName" "INFO"
Log "Repository: $GitHubRepo" "INFO"
Log ""
Log "NEXT STEPS:" "SUCCESS"
Log ""
Log "GitHub Actions workflow is now active!" "SUCCESS"
Log ""
Log "When you push any changes to GitHub (on main branch):" "INFO"
Log "  1. GitHub Actions workflow automatically triggers"
Log "  2. Builds and deploys to Azure Static Web App"
Log "  3. Updates: https://nice-flower-0071a6e03.6.azurestaticapps.net/cockpit.html"
Log ""
Log "To test deployment, make a small change and push:" "INFO"
Log "  Example: Edit cockpit.html, git add, git commit, git push" "INFO"
Log ""
Log "Log file: $LogFile" "INFO"
Log "End time: $(Get-Date)"

Pop-Location

Write-Host ""
Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
Write-Host "GitHub Actions deployment is now configured and active!"
Write-Host ""

Read-Host "Press Enter to close"
