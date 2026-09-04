param(
    [string]$FilePath = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\cockpit.html",
    [string]$ResourceGroup = "rg-boels-d-spow",
    [string]$StaticAppName = "spow-cockpit-64837"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Uploading cockpit.html to Azure" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

if (-not (Test-Path $FilePath)) {
    Write-Host "Error: File not found at $FilePath" -ForegroundColor Red
    exit 1
}

$FileSize = (Get-Item $FilePath).Length
Write-Host "[OK] Found cockpit.html ($FileSize bytes)" -ForegroundColor Green

Write-Host "`nGetting Static Web App details..." -ForegroundColor Green
try {
    $AppInfo = az staticwebapp show --name $StaticAppName --resource-group $ResourceGroup -o json | ConvertFrom-Json
    if (-not $AppInfo) {
        throw "No app returned"
    }
} catch {
    Write-Host "Error: Could not find Static Web App" -ForegroundColor Red
    Write-Host "Run: az login" -ForegroundColor Yellow
    exit 1
}

$AppUrl = "https://$($AppInfo.defaultHostname)"
Write-Host "[OK] Found Static Web App: $StaticAppName" -ForegroundColor Green
Write-Host "     URL: $AppUrl" -ForegroundColor Cyan

Write-Host "`nFinding storage account..." -ForegroundColor Green
try {
    $StorageAcct = az staticwebapp show --name $StaticAppName --resource-group $ResourceGroup --query 'storageAccount' -o json | ConvertFrom-Json
    $StorageAccountName = $StorageAcct.name
    Write-Host "[OK] Storage account: $StorageAccountName" -ForegroundColor Green
} catch {
    Write-Host "Error: Could not find storage account" -ForegroundColor Red
    exit 1
}

Write-Host "`nGetting storage account key..." -ForegroundColor Green
try {
    $KeyResult = az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccountName --query '[0].value' -o tsv
    if (-not $KeyResult) {
        throw "No key returned"
    }
    Write-Host "[OK] Storage key retrieved" -ForegroundColor Green
} catch {
    Write-Host "Error: Could not get storage account key" -ForegroundColor Red
    exit 1
}

Write-Host "`nUploading cockpit.html to storage..." -ForegroundColor Green
try {
    az storage blob upload --account-name $StorageAccountName --account-key $KeyResult --container-name '$web' --name 'cockpit.html' --file $FilePath --overwrite
    Write-Host "[OK] Upload successful!" -ForegroundColor Green
} catch {
    Write-Host "Error during upload: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "[SUCCESS] Deployment Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "`nCockpit is now available at:" -ForegroundColor Green
Write-Host "$AppUrl" -ForegroundColor Cyan
Write-Host "`nOpen this URL in your browser to test login!" -ForegroundColor Green

$null = Read-Host "`nPress Enter to exit"
