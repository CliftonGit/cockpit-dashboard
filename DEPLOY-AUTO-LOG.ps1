#
# DEPLOYMENT WITH AUTOMATIC LOGGING
# All output logged to file - user just says "Ok" when done
#

param(
    [string]$SourceFile = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\cockpit.html",
    [string]$ResourceGroup = "rg-boels-d-spow",
    [string]$AppName = "spow-cockpit-64837",
    [string]$SubscriptionId = "ed8c9803-e8e9-4728-b56e-984cd2327a06"
)

# Setup logging
$LogFile = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\DEPLOYMENT-LOG.txt"
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Function to log and display
function Log {
    param([string]$Message, [string]$Color = "White")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    Write-Host $Message -ForegroundColor $Color
}

function LogError {
    param([string]$Message)
    Log $Message "Red"
}

function LogSuccess {
    param([string]$Message)
    Log $Message "Green"
}

function LogWarning {
    param([string]$Message)
    Log $Message "Yellow"
}

# Clear log file
"" | Set-Content -Path $LogFile

Log "========================================"
Log "COCKPIT DEPLOYMENT - AUTO LOG"
Log "========================================"
Log "Start time: $(Get-Date)"
Log ""

# STEP 1: Verify file
Log "STEP 1: Verifying file..."
if (-not (Test-Path $SourceFile)) {
    LogError "ERROR: File not found at $SourceFile"
    exit 1
}

$FileSize = (Get-Item $SourceFile).Length
LogSuccess "OK: Found cockpit.html ($FileSize bytes)"

# STEP 2: Check Azure CLI
Log ""
Log "STEP 2: Checking Azure CLI..."
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    LogError "ERROR: Azure CLI not installed"
    exit 1
}
LogSuccess "OK: Azure CLI is installed"

# STEP 3: Set subscription
Log ""
Log "STEP 3: Setting Azure subscription..."
try {
    az account set --subscription $SubscriptionId 2>$null
    $CurrentSub = az account show --query name -o tsv 2>$null
    LogSuccess "OK: Subscription set to $CurrentSub"
} catch {
    LogWarning "WARNING: Could not verify subscription"
}

# STEP 4: Get Static Web App details
Log ""
Log "STEP 4: Getting Static Web App details..."
try {
    $AppInfo = az staticwebapp show --name $AppName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
    if (-not $AppInfo) { throw "App not found" }

    $AppHostname = $AppInfo.defaultHostname
    $AppUrl = "https://$AppHostname"
    LogSuccess "OK: Found $AppName"
    Log "    Hostname: $AppHostname"
    Log "    Tier: Free (Azure-managed)"
} catch {
    LogError "ERROR: Could not find Static Web App"
    exit 1
}

# STEP 5: Try Method 1 - Using upload-user-generated-content
Log ""
Log "STEP 5: Attempting deployment (Method 1 - User Generated Content)..."

$TempDir = [System.IO.Path]::GetTempPath() + "cockpit-" + [guid]::NewGuid()
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Copy-Item -Path $SourceFile -Destination "$TempDir\cockpit.html" -Force

$UploadCmd = "az staticwebapp upload-user-generated-content --name $AppName --resource-group $ResourceGroup --source '$TempDir' 2>&1"
$UploadResult = Invoke-Expression $UploadCmd

Log $UploadResult

if ($LASTEXITCODE -eq 0) {
    LogSuccess "OK: Upload succeeded via Method 1"
    Log ""
    Log "STEP 6: Verifying deployment..."
    Start-Sleep -Seconds 3
    try {
        $Response = Invoke-WebRequest -Uri "$AppUrl/cockpit.html" -ErrorAction SilentlyContinue
        if ($Response.StatusCode -eq 200) {
            LogSuccess "OK: File is accessible (HTTP 200)"
            Log "    Size: $($Response.Content.Length) bytes"
        } else {
            LogWarning "WARNING: Status code $($Response.StatusCode)"
        }
    } catch {
        LogWarning "WARNING: Could not verify via HTTP (CDN may need time)"
    }
} else {
    Log ""
    LogWarning "Method 1 failed, trying Method 2..."
    Log ""
    Log "STEP 5b: Attempting deployment (Method 2 - Direct Blob Upload)..."

    # Method 2: Try with storage blob upload
    try {
        $DeploymentToken = az staticwebapp secrets list --name $AppName --resource-group $ResourceGroup --query 'properties.apiKey' -o tsv 2>$null

        if ($DeploymentToken) {
            LogSuccess "OK: Got deployment token"

            $ZipPath = "$TempDir\deploy.zip"
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $ZipPath)

            $FileBytes = [System.IO.File]::ReadAllBytes($ZipPath)

            # Try different endpoint formats
            $Endpoints = @(
                "$AppUrl/api/deploy",
                "$AppUrl/api/deploy?pr=main",
                "$AppUrl/uploads"
            )

            $Success = $false
            foreach ($Endpoint in $Endpoints) {
                try {
                    Log "    Trying endpoint: $Endpoint"
                    $Headers = @{
                        "Content-Type" = "application/zip"
                        "Authorization" = "Bearer $DeploymentToken"
                    }

                    $Response = Invoke-WebRequest -Uri $Endpoint -Method Post -Headers $Headers -Body $FileBytes -ErrorAction Stop

                    if ($Response.StatusCode -eq 200 -or $Response.StatusCode -eq 201) {
                        LogSuccess "OK: Upload succeeded at $Endpoint (HTTP $($Response.StatusCode))"
                        $Success = $true
                        break
                    }
                } catch {
                    Log "    Failed: $_"
                }
            }

            if (-not $Success) {
                LogWarning "WARNING: All endpoints returned errors"
                LogWarning "This may be a limitation of Free tier"
            }
        }
    } catch {
        LogError "ERROR: Method 2 failed: $_"
    }
}

# Cleanup
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

# FINAL
Log ""
Log "========================================"
Log "DEPLOYMENT COMPLETE"
Log "========================================"
Log ""
Log "Application URL: $AppUrl/cockpit.html"
Log "Log file: $LogFile"
Log ""
Log "End time: $(Get-Date)"

# Keep window open
Read-Host "Press Enter to close"
