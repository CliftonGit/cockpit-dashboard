# SPoW Cockpit Deployment - Fixed
$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host 'SPoW Cockpit Complete Deployment' -ForegroundColor Green
Write-Host ''

# Verify Azure CLI
$az = (Get-Command az -ErrorAction SilentlyContinue)
if (-not $az) {
    Write-Error 'Azure CLI (az) is not installed or not in PATH. Install Azure CLI first.'
    exit 1
}

$resourceGroup = 'rg-boels-d-spow'
$appName = 'SPoW-Cockpit'
$staticAppName = 'spow-cockpit-' + (Get-Random -Minimum 10000 -Maximum 99999)
$location = 'westeurope'

Write-Host '[1/7] Checking Azure login...' -ForegroundColor Green
$account = az account show --query userPrincipalName -o tsv 2>$null
if (-not $account) {
    az login | Out-Null
    $account = az account show --query userPrincipalName -o tsv
}
$tenantId = az account show --query tenantId -o tsv
Write-Host "Logged in as: $account" -ForegroundColor Green

Write-Host '[2/7] Entra app registration...' -ForegroundColor Green
$existingAppJson = az ad app list --display-name $appName -o json
$existingApps = $existingAppJson | ConvertFrom-Json

if ($existingApps.Count -gt 0) {
    $appObj = $existingApps[0]
} else {
    $appObj = (az ad app create --display-name $appName --sign-in-audience AzureADMultipleOrgs -o json | ConvertFrom-Json)
}

$clientId = $appObj.appId
$objectId = $appObj.id

Write-Host '[3/7] Creating client secret...' -ForegroundColor Green
$secretObj = (az ad app credential reset --id $objectId --append -o json | ConvertFrom-Json)
$clientSecret = $secretObj.password

Write-Host '[4/7] Creating Static Web App...' -ForegroundColor Green
$swaObj = (az staticwebapp create --resource-group $resourceGroup --name $staticAppName --location $location --sku Free -o json | ConvertFrom-Json)
$staticAppUrl = $swaObj.defaultHostname

Write-Host ''
Write-Host 'DEPLOYMENT COMPLETE' -ForegroundColor Green
Write-Host "Client ID: $clientId"
Write-Host "Tenant ID: $tenantId"
Write-Host "Client Secret: $clientSecret"
Write-Host "Static App URL: https://$staticAppUrl"
Read-Host 'Press Enter to exit'
