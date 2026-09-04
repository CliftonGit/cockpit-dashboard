param(
    [string]$FilePath = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\cockpit.html",
    [string]$ResourceGroup = "rg-boels-d-spow"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Finding Storage Account and Uploading" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`nStep 1: List all storage accounts in resource group..." -ForegroundColor Yellow
$StorageAccounts = az storage account list --resource-group $ResourceGroup --output json | ConvertFrom-Json
Write-Host "Found $($StorageAccounts.Count) storage account(s)"

if ($StorageAccounts.Count -eq 0) {
    Write-Host "ERROR: No storage accounts found!" -ForegroundColor Red
    exit 1
}

$StorageAccountName = $StorageAccounts[0].name
Write-Host "Using storage account: $StorageAccountName" -ForegroundColor Green

Write-Host "`nStep 2: Get storage account key..." -ForegroundColor Yellow
$KeyResult = az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccountName --query '[0].value' -o tsv
if (-not $KeyResult) {
    Write-Host "ERROR: Could not get key" -ForegroundColor Red
    exit 1
}
Write-Host "Key retrieved successfully" -ForegroundColor Green

Write-Host "`nStep 3: Check what's in the '$web' container..." -ForegroundColor Yellow
$Blobs = az storage blob list --account-name $StorageAccountName --account-key $KeyResult --container-name '$web' -o json 2>&1 | ConvertFrom-Json
if ($Blobs -and $Blobs.Count -gt 0) {
    Write-Host "Current files:"
    $Blobs | ForEach-Object { Write-Host "  - $($_.name)" }
} else {
    Write-Host "Container is empty" -ForegroundColor Cyan
}

Write-Host "`nStep 4: Uploading cockpit.html..." -ForegroundColor Yellow
Write-Host "Source: $FilePath"
Write-Host "Target: $StorageAccountName/`$web/cockpit.html"

try {
    $Result = az storage blob upload `
        --account-name $StorageAccountName `
        --account-key $KeyResult `
        --container-name '$web' `
        --name 'cockpit.html' `
        --file $FilePath `
        --overwrite `
        -o json 2>&1

    if ($Result -like "*error*" -or $Result -like "*Error*") {
        Write-Host "Upload error: $Result" -ForegroundColor Red
    } else {
        Write-Host "Upload completed!" -ForegroundColor Green
    }
} catch {
    Write-Host "Exception during upload: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nStep 5: Verifying upload..." -ForegroundColor Yellow
$VerifyBlobs = az storage blob list --account-name $StorageAccountName --account-key $KeyResult --container-name '$web' -o json 2>&1 | ConvertFrom-Json
if ($VerifyBlobs) {
    Write-Host "Files now in container:"
    $VerifyBlobs | ForEach-Object { Write-Host "  - $($_.name) (Size: $($_.properties.contentLength) bytes)" }
} else {
    Write-Host "ERROR: Container still empty after upload!" -ForegroundColor Red
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Done! Access your app at:" -ForegroundColor Green
Write-Host "https://nice-flower-0071a6e03.6.azurestaticapps.net/cockpit.html" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$null = Read-Host "`nPress Enter to exit"
