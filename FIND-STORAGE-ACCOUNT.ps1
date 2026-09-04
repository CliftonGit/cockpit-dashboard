param(
    [string]$StaticAppName = "spow-cockpit-64837",
    [string]$ResourceGroup = "rg-boels-d-spow"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Finding Storage Account for Static Web App" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`nStep 1: Get all storage accounts in subscription..." -ForegroundColor Yellow
$AllAccounts = az storage account list -o json | ConvertFrom-Json
Write-Host "Found $($AllAccounts.Count) storage account(s) total"

Write-Host "`nAll storage accounts:"
$AllAccounts | ForEach-Object {
    Write-Host "  - $($_.name) (RG: $($_.resourceGroup))"
}

Write-Host "`nStep 2: Look for accounts with 'spow' or 'cockpit' in the name..." -ForegroundColor Yellow
$CandidateAccounts = $AllAccounts | Where-Object { $_.name -like "*spow*" -or $_.name -like "*cockpit*" }
if ($CandidateAccounts) {
    Write-Host "Found $($CandidateAccounts.Count) candidate(s):"
    $CandidateAccounts | ForEach-Object {
        Write-Host "  - $($_.name) (RG: $($_.resourceGroup))"
    }
} else {
    Write-Host "No obvious matches. Checking storage accounts starting with 'stg'..." -ForegroundColor Yellow
    $CandidateAccounts = $AllAccounts | Where-Object { $_.name -like "stg*" }
    if ($CandidateAccounts) {
        Write-Host "Found $($CandidateAccounts.Count) storage account(s) starting with 'stg':"
        $CandidateAccounts | ForEach-Object {
            Write-Host "  - $($_.name) (RG: $($_.resourceGroup))"
        }
    }
}

if ($CandidateAccounts.Count -eq 1) {
    $StorageAccountName = $CandidateAccounts[0].name
    $StorageRG = $CandidateAccounts[0].resourceGroup

    Write-Host "`nStep 3: Using storage account: $StorageAccountName" -ForegroundColor Green
    Write-Host "Resource group: $StorageRG"

    Write-Host "`nStep 4: Getting storage account key..." -ForegroundColor Yellow
    $KeyResult = az storage account keys list --resource-group $StorageRG --account-name $StorageAccountName --query '[0].value' -o tsv

    if ($KeyResult) {
        Write-Host "Key retrieved successfully" -ForegroundColor Green

        Write-Host "`nStep 5: Listing containers..." -ForegroundColor Yellow
        $Containers = az storage container list --account-name $StorageAccountName --account-key $KeyResult -o json | ConvertFrom-Json
        $Containers | ForEach-Object { Write-Host "  - $($_.name)" }

        Write-Host "`nStep 6: List files in '$web' container..." -ForegroundColor Yellow
        $Blobs = az storage blob list --account-name $StorageAccountName --account-key $KeyResult --container-name '$web' -o json 2>&1 | ConvertFrom-Json
        if ($Blobs -and $Blobs.Count -gt 0) {
            Write-Host "Current files:"
            $Blobs | ForEach-Object { Write-Host "  - $($_.name)" }
        } else {
            Write-Host "Container is empty" -ForegroundColor Yellow
        }

        Write-Host "`nSTORAGE ACCOUNT FOUND!" -ForegroundColor Green
        Write-Host "Name: $StorageAccountName" -ForegroundColor Cyan
        Write-Host "Resource Group: $StorageRG" -ForegroundColor Cyan
    } else {
        Write-Host "ERROR: Could not get key" -ForegroundColor Red
    }
} else {
    Write-Host "`nMultiple candidates or none found. Please specify storage account manually." -ForegroundColor Yellow
    if ($CandidateAccounts.Count -gt 1) {
        Write-Host "Use one of the accounts listed above." -ForegroundColor Yellow
    }
}

$null = Read-Host "`nPress Enter to exit"
