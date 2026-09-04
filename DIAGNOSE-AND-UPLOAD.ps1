param(
    [string]$FilePath = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\cockpit.html",
    [string]$ResourceGroup = "rg-boels-d-spow",
    [string]$StaticAppName = "spow-cockpit-64837"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Diagnostic: Checking Storage Account" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`nStep 1: Get Static Web App info..." -ForegroundColor Yellow
$AppInfo = az staticwebapp show --name $StaticAppName --resource-group $ResourceGroup -o json | ConvertFrom-Json
Write-Host "AppId: $($AppInfo.id)"
Write-Host "Default hostname: $($AppInfo.defaultHostname)"

Write-Host "`nStep 2: Get Storage Account..." -ForegroundColor Yellow
$StorageAcct = az staticwebapp show --name $StaticAppName --resource-group $ResourceGroup --query 'storageAccount' -o json | ConvertFrom-Json
$StorageAccountName = $StorageAcct.name
Write-Host "Storage account name: $StorageAccountName"

Write-Host "`nStep 3: Get Storage Account Key..." -ForegroundColor Yellow
$KeyResult = az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccountName --query '[0].value' -o tsv
if ($KeyResult) {
    Write-Host "Key retrieved successfully"
} else {
    Write-Host "ERROR: Could not get key" -ForegroundColor Red
    exit 1
}

Write-Host "`nStep 4: List current files in '$web' container..." -ForegroundColor Yellow
$Blobs = az storage blob list --account-name $StorageAccountName --account-key $KeyResult --container-name '$web' --output table
Write-Host $Blobs

Write-Host "`nStep 5: Upload cockpit.html..." -ForegroundColor Yellow
Write-Host "Source file: $FilePath"
Write-Host "File size: $((Get-Item $FilePath).Length) bytes"

$UploadOutput = az storage blob upload `
    --account-name $StorageAccountName `
    --account-key $KeyResult `
    --container-name '$web' `
    --name 'cockpit.html' `
    --file $FilePath `
    --overwrite `
    --verbose 2>&1

Write-Host "`nUpload output:"
Write-Host $UploadOutput

Write-Host "`nStep 6: Verify upload by listing files again..." -ForegroundColor Yellow
$BlobsAfter = az storage blob list --account-name $StorageAccountName --account-key $KeyResult --container-name '$web' --output table
Write-Host $BlobsAfter

Write-Host "`nStep 7: Get cockpit.html blob details..." -ForegroundColor Yellow
$BlobDetails = az storage blob show --account-name $StorageAccountName --account-key $KeyResult --container-name '$web' --name 'cockpit.html' -o json 2>&1
Write-Host $BlobDetails

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Diagnostic Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "`nCockpit URL: https://$($AppInfo.defaultHostname)/cockpit.html" -ForegroundColor Cyan

$null = Read-Host "`nPress Enter to exit"
