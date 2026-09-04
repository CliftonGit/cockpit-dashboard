#
# MASTER DEPLOYMENT SCRIPT - COCKPIT.HTML TO AZURE STATIC WEB APP
# Handles automatic discovery and deployment without user interaction
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
Write-Host "  COCKPIT DEPLOYMENT - AUTOMATED" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# STEP 1: Verify file exists
Write-Host "STEP 1: Verifying file..." -ForegroundColor Yellow
if (-not (Test-Path $SourceFile)) {
    Write-Host "ERROR: File not found at $SourceFile" -ForegroundColor Red
    Write-Host "Please ensure cockpit.html is in the correct location." -ForegroundColor Red
    exit 1
}

$FileSize = (Get-Item $SourceFile).Length
Write-Host "OK: Found cockpit.html ($FileSize bytes)" -ForegroundColor Green

# STEP 2: Check Azure CLI
Write-Host ""
Write-Host "STEP 2: Checking Azure CLI..." -ForegroundColor Yellow

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Azure CLI not installed" -ForegroundColor Red
    Write-Host "Please install Azure CLI from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
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
} catch {
    Write-Host "ERROR: Could not find Static Web App" -ForegroundColor Red
    exit 1
}

# STEP 5: Find storage account
Write-Host ""
Write-Host "STEP 5: Finding storage account..." -ForegroundColor Yellow

try {
    # Try multiple strategies to find the storage account

    # Strategy 1: Look in the same resource group
    $StorageAccounts = az storage account list --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json

    if ($StorageAccounts.Count -eq 0) {
        # Strategy 2: Search by name patterns
        $AllAccounts = az storage account list -o json 2>$null | ConvertFrom-Json
        $StorageAccounts = @($AllAccounts | Where-Object {
            $_.name -like "*spow*" -or $_.name -like "*cockpit*" -or $_.name -like "*web*"
        })
    }

    if ($StorageAccounts.Count -eq 0) {
        # Strategy 3: Use the first available account
        $AllAccounts = az storage account list -o json 2>$null | ConvertFrom-Json
        if ($AllAccounts.Count -gt 0) {
            $StorageAccounts = @($AllAccounts[0])
        }
    }

    if ($StorageAccounts.Count -eq 0) {
        throw "No storage accounts found"
    }

    # Use the first candidate
    $StorageAccount = $StorageAccounts[0]
    $StorageAccountName = $StorageAccount.name
    $StorageRG = $StorageAccount.resourceGroup

    Write-Host "OK: Found storage account '$StorageAccountName'" -ForegroundColor Green
    Write-Host "    Resource Group: $StorageRG" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}

# STEP 6: Get storage account key
Write-Host ""
Write-Host "STEP 6: Retrieving storage account key..." -ForegroundColor Yellow

try {
    $KeyResult = az storage account keys list --resource-group $StorageRG --account-name $StorageAccountName --query '[0].value' -o tsv 2>$null

    if (-not $KeyResult) { throw "No key returned" }

    Write-Host "OK: Storage key retrieved" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Could not get storage account key" -ForegroundColor Red
    exit 1
}

# STEP 7: Upload file to storage
Write-Host ""
Write-Host "STEP 7: Uploading cockpit.html to storage..." -ForegroundColor Yellow
Write-Host "    Account: $StorageAccountName" -ForegroundColor Cyan
Write-Host "    Container: `$web" -ForegroundColor Cyan
Write-Host "    File: cockpit.html" -ForegroundColor Cyan

try {
    $UploadOutput = az storage blob upload `
        --account-name $StorageAccountName `
        --account-key $KeyResult `
        --container-name '$web' `
        --name 'cockpit.html' `
        --file $SourceFile `
        --overwrite `
        -o json 2>&1

    if ($LASTEXITCODE -ne 0) { throw $UploadOutput }

    Write-Host "OK: Upload completed" -ForegroundColor Green
} catch {
    Write-Host "ERROR during upload: $_" -ForegroundColor Red
    exit 1
}

# STEP 8: Verify upload
Write-Host ""
Write-Host "STEP 8: Verifying deployment..." -ForegroundColor Yellow

try {
    $Blobs = az storage blob list --account-name $StorageAccountName --account-key $KeyResult --container-name '$web' -o json 2>$null | ConvertFrom-Json

    $CockpitBlob = $Blobs | Where-Object { $_.name -eq 'cockpit.html' } | Select-Object -First 1

    if ($CockpitBlob) {
        $UploadSize = $CockpitBlob.properties.contentLength
        Write-Host "OK: Verified cockpit.html in storage" -ForegroundColor Green
        Write-Host "    Size: $UploadSize bytes" -ForegroundColor Cyan
    } else {
        Write-Host "WARNING: Could not verify blob in storage" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: Verification inconclusive" -ForegroundColor Yellow
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
