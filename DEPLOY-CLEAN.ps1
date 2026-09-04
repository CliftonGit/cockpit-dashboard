# SPoW Cockpit Deployment - CLEAN VERSION
$ErrorActionPreference = "Continue"

Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SPoW Cockpit Complete Deployment" -ForegroundColor Green
Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan

$resourceGroup = "rg-boels-d-spow"
$appName = "SPoW-Cockpit"
$staticAppName = "spow-cockpit-$(Get-Random -Minimum 10000 -Maximum 99999)"
$location = "westeurope"

# Step 1: Verify Azure login
Write-Host "`n[1/7] Checking Azure login..." -ForegroundColor Green
$account = az account show --query "userPrincipalName" -o tsv 2>$null
$tenantId = az account show --query "tenantId" -o tsv

if (-not $account) {
    Write-Host "Not logged in. Running: az login" -ForegroundColor Yellow
    az login
    $account = az account show --query "userPrincipalName" -o tsv
}
Write-Host "✓ Logged in as: $account" -ForegroundColor Green

# Step 2: Create or find Entra app
Write-Host "`n[2/7] Entra app registration..." -ForegroundColor Green
$appFilter = "displayName eq '$appName'"
$existingApp = az ad app list --filter $appFilter --query "[0]" -o json 2>$null

if ($existingApp -and $existingApp.Trim() -ne '') {
    $appObj = $existingApp | ConvertFrom-Json
    $clientId = $appObj.appId
    $objectId = $appObj.id
    Write-Host "Using existing app: $clientId" -ForegroundColor Green
} else {
    Write-Host "Creating new app..." -ForegroundColor Yellow
    $appJson = az ad app create --display-name $appName --sign-in-audience AzureADMultipleOrgs -o json 2>$null
    $appObj = $appJson | ConvertFrom-Json
    $clientId = $appObj.appId
    $objectId = $appObj.id
    Write-Host "Created app: $clientId" -ForegroundColor Green
}

# Step 3: Create client secret
Write-Host "`n[3/7] Creating client secret..." -ForegroundColor Green
$secretJson = az ad app credential create --id $objectId --display-name "Cockpit-Access" -o json 2>$null
$secretObj = $secretJson | ConvertFrom-Json
$clientSecret = $secretObj.secretText
Write-Host "Secret created" -ForegroundColor Green

# Step 4: Add Dataverse permissions
Write-Host "`n[4/7] Adding Dataverse API permissions..." -ForegroundColor Green
az ad app permission add --id $clientId --api "00000007-0000-0000-c000-000000000000" --api-permissions "78ce3f0f-a1ce-49c2-8cde-64b5c0896db0=Scope" 2>$null
Write-Host "Dataverse permissions added" -ForegroundColor Green

# Step 5: Create Static Web App
Write-Host "`n[5/7] Creating Static Web App..." -ForegroundColor Green
$swaJson = az staticwebapp create --resource-group $resourceGroup --name $staticAppName --location $location --sku Free -o json 2>$null
$swaObj = $swaJson | ConvertFrom-Json
$staticAppUrl = $swaObj.defaultHostname
Write-Host "Static Web App created: $staticAppName" -ForegroundColor Green
Write-Host "  URL: https://$staticAppUrl" -ForegroundColor Cyan

# Step 6: Update redirect URIs
Write-Host "`n[6/7] Setting redirect URIs..." -ForegroundColor Green
$redirectUri = "https://$staticAppUrl/"
az ad app update --id $objectId --web-redirect-uris $redirectUri 2>$null
Write-Host "Redirect URIs updated" -ForegroundColor Green

# Step 7: Create budget alert
Write-Host "`n[7/7] Creating budget alert..." -ForegroundColor Green
az consumption budget create --resource-group $resourceGroup --name "SPoW-Development-Budget" --category "Cost" --limit 25 --time-period "Monthly" --start-date "2026-09-01" --notifications-enabled-status "Enabled" --notification-type "Email" --contact-emails "clifton.dobbelsteyn@boels.nl" -o json 2>$null | Out-Null
Write-Host "Budget alert created (25 euros/month)" -ForegroundColor Green

# Summary
Write-Host "`n════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`nSAVE THESE CREDENTIALS:" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────" -ForegroundColor Yellow
Write-Host "Client ID:     $clientId" -ForegroundColor White
Write-Host "Tenant ID:     $tenantId" -ForegroundColor White
Write-Host "Client Secret: $clientSecret" -ForegroundColor White
Write-Host "Static App URL: https://$staticAppUrl" -ForegroundColor White
Write-Host "────────────────────────────────────────────" -ForegroundColor Yellow

Write-Host "`nNEXT STEPS:" -ForegroundColor Green
Write-Host "1. Open cockpit.html in notepad or VSCode" -ForegroundColor White
Write-Host "2. Find: clientId: YOUR_APP_ID_HERE" -ForegroundColor White
Write-Host "3. Replace with Client ID above" -ForegroundColor White
Write-Host "4. Find: tenantId: YOUR_TENANT_ID_HERE" -ForegroundColor White
Write-Host "5. Replace with Tenant ID above" -ForegroundColor White
Write-Host "6. Save cockpit.html" -ForegroundColor White
Write-Host "7. Go to Azure Portal, search for $staticAppName" -ForegroundColor White
Write-Host "8. Click Browse, then upload cockpit.html" -ForegroundColor White
Write-Host "9. Open https://$staticAppUrl and test login" -ForegroundColor White

$null = Read-Host "`nPress Enter to exit"
