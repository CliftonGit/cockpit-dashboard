#
# Deploy using Static Web App deployment token (REST API)
#

param(
    [string]$SourceFile = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\cockpit.html",
    [string]$ResourceGroup = "rg-boels-d-spow",
    [string]$AppName = "spow-cockpit-64837",
    [string]$SubscriptionId = "ed8c9803-e8e9-4728-b56e-984cd2327a06"
)

$LogFile = "C:\Users\dobbec\OneDrive - Boels Group\Documents\Changes\DEPLOYMENT-TOKEN-LOG.txt"
"" | Set-Content -Path $LogFile

function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Timestamp] $Message"
    Write-Host $Message
}

Log "========================================"
Log "DEPLOYMENT WITH TOKEN"
Log "========================================"
Log ""

# Setup
az account set --subscription $SubscriptionId 2>$null
$App = az staticwebapp show --name $AppName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
$AppHostname = $App.defaultHostname
$AppUrl = "https://$AppHostname"

Log "Verifying source file..."
if (-not (Test-Path $SourceFile)) {
    Log "ERROR: File not found"
    exit 1
}
Log "OK: File found ($((Get-Item $SourceFile).Length) bytes)"
Log ""

Log "Getting deployment token..."
$DeploymentToken = az staticwebapp secrets list --name $AppName --resource-group $ResourceGroup --query 'properties.apiKey' -o tsv 2>$null

if (-not $DeploymentToken) {
    Log "ERROR: Could not get deployment token"
    exit 1
}

Log "OK: Got token (length: $($DeploymentToken.Length))"
Log ""

# Read file content
$FileContent = [System.IO.File]::ReadAllText($SourceFile)
Log "File content length: $($FileContent.Length) characters"
Log ""

# Try multiple endpoint formats
$Endpoints = @(
    @{
        Name = "Method 1: /api/deploy (POST)"
        Url = "$AppUrl/api/deploy"
        Method = "Post"
        Headers = @{
            "Authorization" = "Bearer $DeploymentToken"
            "Content-Type" = "application/octet-stream"
        }
        Body = $FileContent
    },
    @{
        Name = "Method 2: /api/deploy (PUT)"
        Url = "$AppUrl/api/deploy"
        Method = "Put"
        Headers = @{
            "Authorization" = "Bearer $DeploymentToken"
            "Content-Type" = "application/octet-stream"
        }
        Body = $FileContent
    },
    @{
        Name = "Method 3: /api/deploy (with query params)"
        Url = "$AppUrl/api/deploy?file=cockpit.html"
        Method = "Post"
        Headers = @{
            "Authorization" = "Bearer $DeploymentToken"
            "Content-Type" = "application/octet-stream"
        }
        Body = $FileContent
    },
    @{
        Name = "Method 4: /uploads (POST)"
        Url = "$AppUrl/uploads"
        Method = "Post"
        Headers = @{
            "Authorization" = "Bearer $DeploymentToken"
            "Content-Type" = "application/octet-stream"
        }
        Body = $FileContent
    },
    @{
        Name = "Method 5: Direct file upload with form data"
        Url = "$AppUrl/api/deploy"
        Method = "Post"
        Headers = @{
            "Authorization" = "Bearer $DeploymentToken"
        }
        FormFile = $SourceFile
    }
)

Log "Attempting deployment with $($Endpoints.Count) methods..."
Log ""

$Success = $false

foreach ($endpoint in $Endpoints) {
    Log "Trying: $($endpoint.Name)"
    Log "  Endpoint: $($endpoint.Url)"

    try {
        if ($endpoint.FormFile) {
            # Try file upload
            $Response = Invoke-WebRequest -Uri $endpoint.Url `
                -Method $endpoint.Method `
                -Headers $endpoint.Headers `
                -InFile $endpoint.FormFile `
                -ErrorAction Stop

            Log "  Response: HTTP $($Response.StatusCode)"
            $Success = $true
        } else {
            # Try direct content upload
            $Response = Invoke-WebRequest -Uri $endpoint.Url `
                -Method $endpoint.Method `
                -Headers $endpoint.Headers `
                -Body $endpoint.Body `
                -ErrorAction Stop

            Log "  Response: HTTP $($Response.StatusCode)"
            if ($Response.StatusCode -eq 200 -or $Response.StatusCode -eq 201 -or $Response.StatusCode -eq 202) {
                Log "  SUCCESS!"
                $Success = $true
                break
            }
        }
    } catch {
        $ErrorMsg = $_.Exception.Message
        if ($_.Exception.Response) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
            Log "  Response: HTTP $StatusCode"
            Log "  Error: $ErrorMsg"
        } else {
            Log "  Error: $ErrorMsg"
        }
    }

    Log ""
}

if ($Success) {
    Log "========================================"
    Log "DEPLOYMENT SUCCESSFUL!"
    Log "========================================"
    Log ""
    Log "File deployed to: $AppUrl/cockpit.html"
    Log ""
    Log "Waiting for CDN to propagate..."
    Start-Sleep -Seconds 3

    # Verify
    try {
        $Check = Invoke-WebRequest -Uri "$AppUrl/cockpit.html" -ErrorAction SilentlyContinue
        if ($Check.StatusCode -eq 200) {
            Log "Verification: HTTP 200 - File is accessible!"
        }
    } catch {
        Log "Verification: Could not reach file (may be propagating)"
    }
} else {
    Log "========================================"
    Log "DEPLOYMENT FAILED"
    Log "========================================"
    Log ""
    Log "All deployment methods failed."
    Log ""
    Log "For Free Tier Static Web Apps:"
    Log "  1. The standard deployment method requires GitHub/Azure DevOps integration"
    Log "  2. Alternative: Upgrade to Standard tier for storage account access"
    Log "  3. Alternative: Set up GitHub Actions workflow for deployment"
    Log ""
}

Log ""
Log "End time: $(Get-Date)"

Read-Host "Press Enter to close"
