#
# MASTER DEPLOYMENT SCRIPT V2 - COCKPIT.HTML TO AZURE STATIC WEB APP
# Fixed storage account discovery
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
Write-Host "  COCKPIT DEPLOYMENT - AUTOMATED V2" -ForegroundColor Green
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
    $AppId = $AppInfo.id
    Write-Host "OK: Found $AppName" -ForegroundColor Green
    Write-Host "    Hostname: $AppHostname" -ForegroundColor Cyan
    Write-Host "    ID: $AppId" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: Could not find Static Web App" -ForegroundColor Red
    exit 1
}

# STEP 5: Find storage account associated with Static Web App
Write-Host ""
Write-Host "STEP 5: Finding storage account for Static Web App..." -ForegroundColor Yellow

try {
    # Get all storage accounts and look for the one with $web container
    $AllAccounts = az storage account list -o json 2>$null | ConvertFrom-Json
    $StorageAccount = $null

    foreach ($account in $AllAccounts) {
        $AccountName = $account.name
        $AccountRG = $account.resourceGroup

        # Try to list containers in this account
        $Containers = az storage container list --account-name $AccountName --auth-mode login -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue

        if ($Containers) {
            $HasWebContainer = $Containers | Where-Object { $_.name -eq '$web' }
            if ($HasWebContainer) {
                $StorageAccount = $account
                Write-Host "OK: Found storage account with \$web container: '$AccountName'" -ForegroundColor Green
                Write-Host "    Resource Group: $AccountRG" -ForegroundColor Cyan
                break
            }
        }
    }

    if (-not $StorageAccount) {
        # If no $web container found, try with access key method
        Write-Host "    Trying with storage keys..." -ForegroundColor Yellow

        foreach ($account in $AllAccounts) {
            $AccountName = $account.name
            $AccountRG = $account.resourceGroup

            try {
                $Key = az storage account keys list --resource-group $AccountRG --account-name $AccountName --query '[0].value' -o tsv 2>$null
                if ($Key) {
                    $Containers = az storage container list --account-name $AccountName --account-key $Key -o json 2>$null | ConvertFrom-Json

                    if ($Containers) {
                        $HasWebContainer = $Containers | Where-Object { $_.name -eq '$web' }
                        if ($HasWebContainer) {
                            $StorageAccount = $account
                            Write-Host "OK: Found storage account with \$web container: '$AccountName'" -ForegroundColor Green
                            Write-Host "    Resource Group: $AccountRG" -ForegroundColor Cyan
                            break
                        }
                    }
                }
            } catch {
                # Continue to next account
            }
        }
    }

    if (-not $StorageAccount) {
        throw "No storage account with $web container found"
    }

    $StorageAccountName = $StorageAccount.name
    $StorageRG = $StorageAccount.resourceGroup
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
Write-Host "    Container: \$web" -ForegroundColor Cyan
Write-Host "    File: cockpit.html" -ForegroundColor Cyan

try {
    $UploadOutput = az storage blob upload `
        --account-name $StorageAccountName `
        --account-key $KeyResult `
        --container-name '$web' `
        --name 'cockpit.html' `
        --file $SourceFile `
        --overwrite `
        --content-type 'text/html' `
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
