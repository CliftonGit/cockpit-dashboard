#
# Diagnostic script to understand Azure Static Web App setup
#

param(
    [string]$ResourceGroup = "rg-boels-d-spow",
    [string]$AppName = "spow-cockpit-64837",
    [string]$SubscriptionId = "ed8c9803-e8e9-4728-b56e-984cd2327a06"
)

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  AZURE SETUP DIAGNOSTICS" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription
az account set --subscription $SubscriptionId 2>$null

Write-Host "1. STATIC WEB APP DETAILS:" -ForegroundColor Yellow
$App = az staticwebapp show --name $AppName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
Write-Host "   Name: $($App.name)"
Write-Host "   Hostname: $($App.defaultHostname)"
Write-Host "   SKU: $($App.sku.name)"
Write-Host "   ID: $($App.id)"
Write-Host ""

Write-Host "2. RESOURCE GROUP: $ResourceGroup" -ForegroundColor Yellow
$Resources = az resource list --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
foreach ($res in $Resources) {
    Write-Host "   - $($res.type): $($res.name)"
}
Write-Host ""

Write-Host "3. ALL STORAGE ACCOUNTS IN SUBSCRIPTION:" -ForegroundColor Yellow
$AllAccounts = az storage account list -o json 2>$null | ConvertFrom-Json
foreach ($account in $AllAccounts) {
    Write-Host "   - Name: $($account.name)"
    Write-Host "     RG: $($account.resourceGroup)"
    Write-Host "     Kind: $($account.kind)"

    # Try to list containers
    try {
        $Key = az storage account keys list --resource-group $account.resourceGroup --account-name $account.name --query '[0].value' -o tsv 2>$null
        if ($Key) {
            $Containers = az storage container list --account-name $account.name --account-key $Key -o json 2>$null | ConvertFrom-Json
            if ($Containers) {
                Write-Host "     Containers: $($Containers | ForEach-Object { $_.name } | Join-String -Separator ', ')"
            }
        }
    } catch {}
}
Write-Host ""

Write-Host "4. STATIC WEB APP CONFIGURATION:" -ForegroundColor Yellow
Write-Host $App | ConvertTo-Json -Depth 5
Write-Host ""

Write-Host "5. STATIC WEB APP SECRETS (Deployment Info):" -ForegroundColor Yellow
try {
    $Secrets = az staticwebapp secrets list --name $AppName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
    Write-Host $Secrets | ConvertTo-Json -Depth 5
} catch {
    Write-Host "   Could not retrieve secrets"
}
Write-Host ""
