#
# Find correct deployment method for Free Tier Static Web App
#

param(
    [string]$ResourceGroup = "rg-boels-d-spow",
    [string]$AppName = "spow-cockpit-64837",
    [string]$SubscriptionId = "ed8c9803-e8e9-4728-b56e-984cd2327a06"
)

$LogFile = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\DEPLOYMENT-METHOD-LOG.txt"
"" | Set-Content -Path $LogFile

function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Timestamp] $Message"
    Write-Host $Message
}

Log "========================================"
Log "FINDING DEPLOYMENT METHOD"
Log "========================================"
Log ""

# Set subscription
az account set --subscription $SubscriptionId 2>$null

# Get app details
$App = az staticwebapp show --name $AppName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json

Log "App: $($App.name)"
Log "Hostname: $($App.defaultHostname)"
Log "SKU: $($App.sku.name)"
Log "Location: $($App.location)"
Log ""

# List all available staticwebapp commands
Log "AVAILABLE AZ STATICWEBAPP COMMANDS:"
Log ""
$Commands = az staticwebapp --help 2>&1 | Select-String "^\s+\w" | ForEach-Object { $_.Line.Trim() }
foreach ($cmd in $Commands) {
    Log "  $cmd"
}
Log ""

# Check if app has repository connected
Log "REPOSITORY CONFIGURATION:"
Log "  Repository URL: $($App.repositoryUrl)"
Log "  Branch: $($App.branch)"
Log "  Provider: $($App.provider)"
Log ""

# Check for linked storage accounts
Log "CHECKING FOR LINKED STORAGE:"
$StorageAccounts = az storage account list -o json 2>$null | ConvertFrom-Json
Log "  Total storage accounts in subscription: $($StorageAccounts.Count)"

foreach ($account in $StorageAccounts) {
    Log "  - Account: $($account.name) (RG: $($account.resourceGroup))"
}
Log ""

# Try to get deployment secrets/tokens
Log "DEPLOYMENT TOKENS/SECRETS:"
try {
    $Secrets = az staticwebapp secrets list --name $AppName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
    Log "  API Key available: $(if ($Secrets.properties.apiKey) { 'YES' } else { 'NO' })"
} catch {
    Log "  Could not retrieve secrets"
}
Log ""

# List deployment slots or environments
Log "CHECKING DEPLOYMENT SLOTS:"
try {
    $Slots = az staticwebapp environment list --name $AppName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
    if ($Slots) {
        Log "  Environments found: $($Slots.Count)"
        foreach ($slot in $Slots) {
            Log "    - $($slot.name)"
        }
    } else {
        Log "  No environments found"
    }
} catch {
    Log "  Could not list environments"
}
Log ""

Log "========================================"
Log "RECOMMENDATIONS:"
Log "========================================"
Log ""

if ($App.repositoryUrl) {
    Log "App is connected to repository: $($App.repositoryUrl)"
    Log "Deploy by pushing to: $($App.branch) branch"
} else {
    Log "App is NOT connected to a repository."
    Log ""
    Log "For Free Tier Static Web Apps without repository:"
    Log "  Option 1: Connect GitHub repository for auto-deployment"
    Log "  Option 2: Use deployment token with staticwebapp update"
    Log "  Option 3: Use Azure Portal to upload files"
    Log "  Option 4: Convert to Standard tier for storage access"
    Log ""
    Log "Attempting to find upload endpoint..."

    # Try different potential endpoints
    $AppHostname = $App.defaultHostname
    $Endpoints = @(
        "https://$AppHostname/api/upload",
        "https://$AppHostname/api/files",
        "https://$AppHostname/upload",
        "https://$AppHostname/files"
    )

    Log ""
    Log "Testing potential upload endpoints:"
    foreach ($endpoint in $Endpoints) {
        try {
            $response = Invoke-WebRequest -Uri $endpoint -Method Options -ErrorAction SilentlyContinue -TimeoutSec 2
            Log "  $endpoint : $($response.StatusCode)"
        } catch {
            Log "  $endpoint : Not found"
        }
    }
}

Log ""
Log "End time: $(Get-Date)"

Read-Host "Press Enter to close"
