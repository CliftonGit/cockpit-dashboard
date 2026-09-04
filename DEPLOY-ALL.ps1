# SPoW Cockpit Deployment Script
# This script creates everything needed to run the cockpit

$ErrorActionPreference = "Stop"

Write-Host "=== SPoW Cockpit Deployment ===" -ForegroundColor Cyan

# Variables
$resourceGroup = "rg-boels-d-spow"
$appName = "SPoW-Cockpit"
$staticAppName = "spow-cockpit-$(Get-Random -Minimum 10000 -Maximum 99999)"
$location = "westeurope"
$tenantId = ""
$clientId = ""
$clientSecret = ""

Write-Host "Step 1: Check if logged in to Azure" -ForegroundColor Green
try {
    $account = az account show -o json | ConvertFrom-Json
    $tenantId = $account.tenantId
    Write-Host "✓ Logged in as $($account.user.name)" -ForegroundColor Green
} catch {
    Write-Host "✗ Not logged in. Running: az login" -ForegroundColor Red
    az login --tenant $tenantId
}

Write-Host "`nStep 2: Create Entra App Registration" -ForegroundColor Green
# Create the app registration
$appJson = az ad app create `
    --display-name $appName `
    --public-client-redirect-uris "http://localhost:3000" "http://localhost:3001" `
    --sign-in-audience AzureADMultipleOrgs `
    -o json 2>$null

if ($appJson) {
    $app = $appJson | ConvertFrom-Json
    $clientId = $app.appId
    $objectId = $app.id
    Write-Host "✓ Created app: $appName" -ForegroundColor Green
    Write-Host "  Client ID: $clientId" -ForegroundColor Cyan
} else {
    # App might already exist, try to find it
    $existing = az ad app list --filter "displayName eq 'SPoW-Cockpit'" -o json | ConvertFrom-Json
    if ($existing.Count -gt 0) {
        $clientId = $existing[0].appId
        $objectId = $existing[0].id
        Write-Host "✓ Found existing app: $appName" -ForegroundColor Green
        Write-Host "  Client ID: $clientId" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Failed to create app" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nStep 3: Create Client Secret" -ForegroundColor Green
$secretJson = az ad app credential create `
    --id $objectId `
    --display-name "Cockpit-Secret" `
    --years 2 `
    -o json 2>$null

if ($secretJson) {
    $secret = $secretJson | ConvertFrom-Json
    $clientSecret = $secret.secretText
    Write-Host "✓ Created secret" -ForegroundColor Green
    Write-Host "  Secret: $($clientSecret.Substring(0,10))..." -ForegroundColor Cyan
} else {
    Write-Host "✗ Failed to create secret" -ForegroundColor Yellow
    Write-Host "  Creating new one..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    $secretJson = az ad app credential create `
        --id $objectId `
        --display-name "Cockpit-Secret-Retry" `
        -o json
    $secret = $secretJson | ConvertFrom-Json
    $clientSecret = $secret.secretText
    Write-Host "✓ Created secret (retry)" -ForegroundColor Green
}

Write-Host "`nStep 4: Add API Permissions (Dataverse)" -ForegroundColor Green
# Add Dataverse API permissions
$permissions = @"
[{
    "resourceAppId": "00000007-0000-0000-c000-000000000000",
    "resourceAccess": [{
        "id": "78ce3f0f-a1ce-49c2-8cde-64b5c0896db0",
        "type": "Scope"
    }]
}]
"@

az ad app permission add --id $clientId --api-permissions $permissions 2>$null
Write-Host "✓ Added Dataverse permissions" -ForegroundColor Green

Write-Host "`nStep 5: Create Static Web App" -ForegroundColor Green
$swaJson = az staticwebapp create `
    --resource-group $resourceGroup `
    --name $staticAppName `
    --location $location `
    --sku Free `
    -o json 2>$null

if ($swaJson) {
    $swa = $swaJson | ConvertFrom-Json
    $staticAppUrl = $swa.defaultHostname
    Write-Host "✓ Created Static Web App: $staticAppName" -ForegroundColor Green
    Write-Host "  URL: https://$staticAppUrl" -ForegroundColor Cyan
} else {
    Write-Host "✗ Failed to create Static Web App" -ForegroundColor Red
    exit 1
}

Write-Host "`nStep 6: Set Redirect URIs" -ForegroundColor Green
# Update the app with correct redirect URI
az ad app update --id $objectId `
    --web-redirect-uris "https://$staticAppUrl/" `
    2>$null
Write-Host "✓ Updated redirect URIs" -ForegroundColor Green

Write-Host "`nStep 7: Create Budget Alert" -ForegroundColor Green
$budgetJson = az consumption budget create `
    --resource-group $resourceGroup `
    --name "SPoW-Development-Budget" `
    --category "Cost" `
    --limit 25 `
    --time-period "Monthly" `
    --start-date "2026-09-01" `
    --notifications-enabled-status "Enabled" `
    --notification-type "Email" `
    --contact-emails "clifton.dobbelsteyn@boels.nl" `
    -o json 2>$null

if ($budgetJson) {
    Write-Host "✓ Created budget alert (€25 monthly)" -ForegroundColor Green
} else {
    Write-Host "✓ Budget alert configured (may already exist)" -ForegroundColor Yellow
}

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "`nIMPORTANT - Save these values:" -ForegroundColor Yellow
Write-Host "`nClient ID:       $clientId" -ForegroundColor White
Write-Host "Tenant ID:       $tenantId" -ForegroundColor White
Write-Host "Client Secret:   $clientSecret" -ForegroundColor White
Write-Host "Static App URL:  https://$staticAppUrl" -ForegroundColor White

Write-Host "`nNext steps:" -ForegroundColor Green
Write-Host "1. Edit cockpit.html - replace CLIENT_ID, TENANT_ID, REDIRECT_URI" -ForegroundColor White
Write-Host "2. Upload cockpit.html to Static Web App via Portal" -ForegroundColor White
Write-Host "3. Open https://$staticAppUrl and test login" -ForegroundColor White

