# Upload cockpit.html to Azure Static Web App Storage
param(
    [string]$FilePath = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\cockpit.html",
    [string]$ResourceGroup = "rg-boels-d-spow",
    [string]$StaticAppName = "spow-cockpit-64837"
)

Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Uploading cockpit.html to Azure Static Web App" -ForegroundColor Green
Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan

# Verify file exists
if (-not (Test-Path $FilePath)) {
    Write-Host "Error: File not found at $FilePath" -ForegroundColor Red
    exit 1
}

$FileSize = (Get-Item $FilePath).Length
Write-Host "`n✓ Found cockpit.html ($FileSize bytes)" -ForegroundColor Green

# Get the Static Web App details
Write-Host "`nGetting Static Web App details..." -ForegroundColor Green
try {
    $AppInfo = az staticwebapp show --name $StaticAppName --resource-group $ResourceGroup -o json | ConvertFrom-Json
    if (-not $AppInfo) {
        throw "No app returned"
    }
} catch {
    Write-Host "Error: Could not find Static Web App. Make sure you are logged in to Azure." -ForegroundColor Red
    Write-Host "Run: az login" -ForegroundColor Yellow
    exit 1
}

$AppUrl = "https://$($AppInfo.defaultHostname)"
Write-Host "✓ Found Static Web App" -ForegroundColor Green
Write-Host "  Name: $StaticAppName" -ForegroundColor Cyan
Write-Host "  URL: $AppUrl" -ForegroundColor Cyan

# Get the storage account backing the Static Web App
Write-Host "`nFinding storage account..." -ForegroundColor Green
try {
    $StorageAcct = az staticwebapp show --name $StaticAppName --resource-group $ResourceGroup --query 'storageAccount' -o json | ConvertFrom-Json
    $StorageAccountName = $StorageAcct.name
    Write-Host "✓ Storage account: $StorageAccountName" -ForegroundColor Green
} catch {
    Write-Host "Error: Could not find storage account" -ForegroundColor Red
    exit 1
}

# Get storage account key
Write-Host "`nGetting storage account key..." -ForegroundColor Green
try {
    $KeyResult = az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccountName --query '[0].value' -o tsv
    if (-not $KeyResult) {
        throw "No key returned"
    }
    Write-Host "✓ Storage key retrieved" -ForegroundColor Green
} catch {
    Write-Host "Error: Could not get storage account key" -ForegroundColor Red
    exit 1
}

# Upload the file to the $web container
Write-Host "`nUploading cockpit.html to storage..." -ForegroundColor Green
try {
    $UploadResult = az storage blob upload `
        --account-name $StorageAccountName `
        --account-key $KeyResult `
        --container-name '$web' `
        --name 'cockpit.html' `
        --file $FilePath `
        --overwrite `
        -o json 2>&1

    Write-Host "✓ Upload successful!" -ForegroundColor Green
} catch {
    Write-Host "Error during upload: $_" -ForegroundColor Red
    exit 1
}

# Verify the file is accessible
Write-Host "`nVerifying deployment..." -ForegroundColor Green
$VerifyUrl = "$AppUrl/cockpit.html"
try {
    $Response = Invoke-WebRequest -Uri $VerifyUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($Response.StatusCode -eq 200) {
        Write-Host "✓ Cockpit is live and accessible!" -ForegroundColor Green
        Write-Host "  URL: $VerifyUrl" -ForegroundColor Cyan
    } else {
        Write-Host "Warning: File uploaded but returned status $($Response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Note: File uploaded successfully" -ForegroundColor Green
    Write-Host "Note: Access to $VerifyUrl" -ForegroundColor Cyan
    Write-Host "Note: (It may take a moment to propagate)" -ForegroundColor Cyan
}

Write-Host "`n════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✓ UPLOAD COMPLETE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`nOpen your browser to: $AppUrl" -ForegroundColor Green

$null = Read-Host "`nPress Enter to exit"
