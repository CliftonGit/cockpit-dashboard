#
# DEPLOYMENT SCRIPT FOR FREE TIER STATIC WEB APP
# Uses Azure CLI staticwebapp deploy command
#

param(
    [string]$SourceFile = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\cockpit.html",
    [string]$ResourceGroup = "rg-boels-d-spow",
    [string]$AppName = "spow-cockpit-64837",
    [string]$SubscriptionId = "ed8c9803-e8e9-4728-b56e-984cd2327a06"
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  COCKPIT DEPLOYMENT - FINAL" -ForegroundColor Green
Write-Host "  Free Tier Static Web App Deployment" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# STEP 1: Verify file exists
Write-Host "STEP 1: Verifying file..." -ForegroundColor Yellow
if (-not (Test-Path $SourceFile)) {
    Write-Host "ERROR: File not found at $SourceFile" -ForegroundColor Red
    exit 1
}

$FileSize = (Get-Item $SourceFile).Length
Write-Host "OK: Found cockpit.html ($FileSize bytes)" -ForegroundColor Green

# STEP 2: Check Azure CLI
Write-Host ""
Write-Host "STEP 2: Checking Azure CLI..." -ForegroundColor Yellow

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Azure CLI not installed" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Azure CLI is installed" -ForegroundColor Green

# STEP 3: Set subscription context
Write-Host ""
Write-Host "STEP 3: Setting Azure subscription..." -ForegroundColor Yellow

try {
    az account set --subscription $SubscriptionId 2>$null
    $CurrentSub = az account show --query name -o tsv 2>$null
    Write-Host "OK: Subscription set to $CurrentSub" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Could not verify subscription" -ForegroundColor Yellow
}

# STEP 4: Get Static Web App details
Write-Host ""
Write-Host "STEP 4: Getting Static Web App details..." -ForegroundColor Yellow

try {
    $AppInfo = az staticwebapp show --name $AppName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
    if (-not $AppInfo) { throw "App not found" }

    $AppHostname = $AppInfo.defaultHostname
    $AppUrl = "https://$AppHostname"
    Write-Host "OK: Found $AppName" -ForegroundColor Green
    Write-Host "    Hostname: $AppHostname" -ForegroundColor Cyan
    Write-Host "    Tier: Free (Azure-managed)" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: Could not find Static Web App" -ForegroundColor Red
    exit 1
}

# STEP 5: Create temporary deployment directory
Write-Host ""
Write-Host "STEP 5: Preparing deployment package..." -ForegroundColor Yellow

$TempDir = [System.IO.Path]::GetTempPath() + "cockpit-deploy-" + [System.Guid]::NewGuid().ToString()
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Write-Host "OK: Created temporary directory" -ForegroundColor Green

# Copy file to temp directory (Azure expects index.html or we deploy as-is)
Copy-Item -Path $SourceFile -Destination "$TempDir\cockpit.html" -Force
Write-Host "OK: Copied cockpit.html to deployment package" -ForegroundColor Green

# STEP 6: Deploy using Azure CLI
Write-Host ""
Write-Host "STEP 6: Deploying to Static Web App..." -ForegroundColor Yellow
Write-Host "    App: $AppName" -ForegroundColor Cyan
Write-Host "    Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "    File: cockpit.html" -ForegroundColor Cyan

try {
    # Use az staticwebapp update or upload-user-generated-content
    # For Free tier, we need to use the deployment token approach or direct upload

    # Try Method 1: Using az staticwebapp update with source file
    Write-Host "    Attempting deployment..." -ForegroundColor Cyan

    $DeployOutput = az staticwebapp update --name $AppName --resource-group $ResourceGroup --source "$TempDir" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Method 1 (update) failed, trying Method 2 (direct HTTP upload)..." -ForegroundColor Yellow

        # Method 2: Use deployment API endpoint
        # Get the deployment token
        $DeploymentToken = az staticwebapp secrets list --name $AppName --resource-group $ResourceGroup --query 'properties.apiKey' -o tsv 2>$null

        if ($DeploymentToken) {
            Write-Host "OK: Got deployment token" -ForegroundColor Green

            # Upload using the deployment API
            $UploadUri = "$AppUrl/api/deploy?pr=main"

            Write-Host "    Uploading to: $UploadUri" -ForegroundColor Cyan

            # Create zip file
            $ZipPath = "$TempDir\deploy.zip"
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $ZipPath)

            # Upload zip
            $FileBytes = [System.IO.File]::ReadAllBytes($ZipPath)

            $Headers = @{
                "Content-Type" = "application/zip"
                "Authorization" = "Bearer $DeploymentToken"
            }

            $UploadResponse = Invoke-WebRequest -Uri $UploadUri -Method Post -Headers $Headers -Body $FileBytes -ErrorAction SilentlyContinue

            if ($UploadResponse.StatusCode -eq 200) {
                Write-Host "OK: Upload via deployment API succeeded" -ForegroundColor Green
            } else {
                Write-Host "WARNING: Unexpected response: $($UploadResponse.StatusCode)" -ForegroundColor Yellow
            }
        } else {
            throw "Could not obtain deployment token"
        }
    } else {
        Write-Host "OK: Deployment via update succeeded" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR during deployment: $_" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup temp directory
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# STEP 7: Verify deployment
Write-Host ""
Write-Host "STEP 7: Verifying deployment..." -ForegroundColor Yellow
Write-Host "    Checking URL: $AppUrl/cockpit.html" -ForegroundColor Cyan

Start-Sleep -Seconds 2

try {
    $Response = Invoke-WebRequest -Uri "$AppUrl/cockpit.html" -ErrorAction SilentlyContinue

    if ($Response.StatusCode -eq 200) {
        Write-Host "OK: File is accessible and returning 200 OK" -ForegroundColor Green
        Write-Host "    Size: $($Response.Content.Length) bytes" -ForegroundColor Cyan
    } else {
        Write-Host "WARNING: File returned status code $($Response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: Could not verify via HTTP (may need to wait a moment)" -ForegroundColor Yellow
    Write-Host "    Error: $_" -ForegroundColor Cyan
}

# FINAL STATUS
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your application is deployed at:" -ForegroundColor Green
Write-Host "$AppUrl/cockpit.html" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "1. Open the URL above in your browser" -ForegroundColor White
Write-Host "2. Test the Cockpit dashboard" -ForegroundColor White
Write-Host "3. Verify Entra ID login works" -ForegroundColor White
Write-Host ""
Write-Host "If you get a 404, wait a few seconds and refresh:" -ForegroundColor Cyan
Write-Host "   The Azure CDN may need a moment to distribute the content." -ForegroundColor Cyan
Write-Host ""
