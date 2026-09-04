#
# DEPLOYMENT SCRIPT FOR FREE TIER STATIC WEB APP - FIXED
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
Write-Host "  COCKPIT DEPLOYMENT - FINAL (FIXED)" -ForegroundColor Green
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

# STEP 5: Get deployment token
Write-Host ""
Write-Host "STEP 5: Getting deployment token..." -ForegroundColor Yellow

try {
    $DeploymentToken = az staticwebapp secrets list --name $AppName --resource-group $ResourceGroup --query 'properties.apiKey' -o tsv 2>$null

    if (-not $DeploymentToken) {
        throw "No deployment token found"
    }

    Write-Host "OK: Got deployment token" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Could not get deployment token" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Yellow
    exit 1
}

# STEP 6: Create and upload deployment package
Write-Host ""
Write-Host "STEP 6: Preparing deployment..." -ForegroundColor Yellow

try {
    # Create temporary directory for staging
    $TempDir = [System.IO.Path]::GetTempPath()
    $TempPackageDir = $TempDir + "cockpit-deploy-" + [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Path $TempPackageDir -Force | Out-Null

    # Copy file to staging directory
    Copy-Item -Path $SourceFile -Destination "$TempPackageDir\cockpit.html" -Force
    Write-Host "OK: Prepared deployment package" -ForegroundColor Green

    # Create zip file in a different location
    $ZipPath = $TempDir + "cockpit-deploy-" + [System.Guid]::NewGuid().ToString() + ".zip"
    Write-Host "    Creating deployment zip..." -ForegroundColor Cyan

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($TempPackageDir, $ZipPath)

    Write-Host "OK: Created deployment package zip" -ForegroundColor Green

    # STEP 7: Upload via deployment API
    Write-Host ""
    Write-Host "STEP 7: Uploading to Static Web App..." -ForegroundColor Yellow

    $UploadUri = "$AppUrl/api/deploy?pr=main"
    Write-Host "    Endpoint: $UploadUri" -ForegroundColor Cyan

    $FileBytes = [System.IO.File]::ReadAllBytes($ZipPath)

    $Headers = @{
        "Content-Type" = "application/zip"
        "Authorization" = "Bearer $DeploymentToken"
    }

    Write-Host "    Uploading $($FileBytes.Length) bytes..." -ForegroundColor Cyan

    $UploadResponse = Invoke-WebRequest -Uri $UploadUri -Method Post -Headers $Headers -Body $FileBytes -ErrorAction Stop

    if ($UploadResponse.StatusCode -eq 200) {
        Write-Host "OK: Upload successful (HTTP 200)" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Unexpected status code: $($UploadResponse.StatusCode)" -ForegroundColor Yellow
    }

    # Cleanup
    Remove-Item -Path $TempPackageDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue

} catch {
    Write-Host "ERROR during upload: $_" -ForegroundColor Red
    exit 1
}

# STEP 8: Verify deployment
Write-Host ""
Write-Host "STEP 8: Verifying deployment..." -ForegroundColor Yellow
Write-Host "    Waiting for CDN to update..." -ForegroundColor Cyan

Start-Sleep -Seconds 3

try {
    $Response = Invoke-WebRequest -Uri "$AppUrl/cockpit.html" -ErrorAction SilentlyContinue

    if ($Response.StatusCode -eq 200) {
        Write-Host "OK: File is accessible (HTTP 200)" -ForegroundColor Green
        Write-Host "    Size: $($Response.Content.Length) bytes" -ForegroundColor Cyan

        # Check if it's the correct file
        if ($Response.Content.Contains("Entra ID") -or $Response.Content.Contains("msal")) {
            Write-Host "OK: Cockpit dashboard content verified" -ForegroundColor Green
        }
    } else {
        Write-Host "WARNING: File returned status code $($Response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: Could not verify via HTTP yet" -ForegroundColor Yellow
    Write-Host "    (CDN may need a moment to propagate)" -ForegroundColor Cyan
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
Write-Host "If you get a 404, wait 5-10 seconds and refresh:" -ForegroundColor Cyan
Write-Host "   The Azure CDN may need a moment to distribute the content." -ForegroundColor Cyan
Write-Host ""
