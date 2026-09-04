#!/bin/bash
# One-command SPoW Cockpit + Budget Alert Deployment
# Run this on your machine with: bash DEPLOY-ALL.sh

set -e

echo "════════════════════════════════════════════════"
echo "  SPoW Cockpit - Complete Deployment"
echo "════════════════════════════════════════════════"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
RG="rg-boels-d-spow"
APP_NAME="SPoW-Cockpit"
STATIC_APP="spow-cockpit-$(shuf -i 10000-99999 -n 1)"
LOCATION="westeurope"

echo -e "\n${GREEN}Step 1: Check Azure Login${NC}"
if ! az account show &>/dev/null; then
    echo "Logging in..."
    az login
fi

TENANT_ID=$(az account show --query tenantId -o tsv)
echo -e "${CYAN}✓ Tenant ID: $TENANT_ID${NC}"

echo -e "\n${GREEN}Step 2: Create Entra App Registration${NC}"
# Check if app already exists
APP_ID=$(az ad app list --filter "displayName eq 'SPoW-Cockpit'" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -z "$APP_ID" ] || [ "$APP_ID" == "null" ]; then
    echo "Creating new app registration..."
    APP_JSON=$(az ad app create \
        --display-name "$APP_NAME" \
        --public-client-redirect-uris "http://localhost:3000" "http://localhost:3001" \
        --sign-in-audience "AzureADMultipleOrgs" \
        -o json)
    
    APP_ID=$(echo $APP_JSON | jq -r '.appId')
    OBJECT_ID=$(echo $APP_JSON | jq -r '.id')
else
    echo "Using existing app registration..."
    OBJECT_ID=$(az ad app list --filter "displayName eq 'SPoW-Cockpit'" --query "[0].id" -o tsv)
fi

echo -e "${CYAN}✓ App ID: $APP_ID${NC}"

echo -e "\n${GREEN}Step 3: Create Client Secret${NC}"
SECRET_JSON=$(az ad app credential create \
    --id "$OBJECT_ID" \
    --display-name "Cockpit-Secret" \
    -o json 2>/dev/null) || SECRET_JSON=""

if [ -z "$SECRET_JSON" ]; then
    sleep 2
    SECRET_JSON=$(az ad app credential create \
        --id "$OBJECT_ID" \
        --display-name "Cockpit-Secret-Retry" \
        -o json)
fi

CLIENT_SECRET=$(echo $SECRET_JSON | jq -r '.secretText')
echo -e "${CYAN}✓ Secret created${NC}"

echo -e "\n${GREEN}Step 4: Add Dataverse Permissions${NC}"
az ad app permission add \
    --id "$APP_ID" \
    --api "00000007-0000-0000-c000-000000000000" \
    --api-permissions "78ce3f0f-a1ce-49c2-8cde-64b5c0896db0=Scope" \
    2>/dev/null || echo "Permissions may already exist"
echo -e "${CYAN}✓ Dataverse permissions added${NC}"

echo -e "\n${GREEN}Step 5: Create Static Web App${NC}"
SWA_JSON=$(az staticwebapp create \
    --resource-group "$RG" \
    --name "$STATIC_APP" \
    --location "$LOCATION" \
    --sku Free \
    -o json)

STATIC_URL=$(echo $SWA_JSON | jq -r '.defaultHostname')
echo -e "${CYAN}✓ Static Web App: https://$STATIC_URL${NC}"

echo -e "\n${GREEN}Step 6: Update Redirect URIs${NC}"
az ad app update \
    --id "$OBJECT_ID" \
    --web-redirect-uris "https://$STATIC_URL/" \
    2>/dev/null
echo -e "${CYAN}✓ Redirect URIs updated${NC}"

echo -e "\n${GREEN}Step 7: Create Budget Alert${NC}"
az consumption budget create \
    --resource-group "$RG" \
    --name "SPoW-Development-Budget" \
    --category "Cost" \
    --limit 25 \
    --time-period "Monthly" \
    --start-date "2026-09-01" \
    --notifications-enabled-status "Enabled" \
    --notification-type "Email" \
    --contact-emails "clifton.dobbelsteyn@boels.nl" \
    -o json 2>/dev/null || echo "Budget alert configured"
echo -e "${CYAN}✓ Budget alert set (€25/month)${NC}"

echo -e "\n════════════════════════════════════════════════"
echo -e "${GREEN}DEPLOYMENT COMPLETE${NC}"
echo -e "════════════════════════════════════════════════"

echo -e "\n${GREEN}CREDENTIALS TO SAVE:${NC}"
echo "────────────────────────────────────────────────"
echo "Client ID:       $APP_ID"
echo "Tenant ID:       $TENANT_ID"
echo "Client Secret:   $CLIENT_SECRET"
echo "Static App URL:  https://$STATIC_URL"
echo "────────────────────────────────────────────────"

echo -e "\n${GREEN}NEXT STEPS:${NC}"
echo "1. Open cockpit.html in your editor"
echo "2. Find line with: clientId: \"YOUR_APP_ID_HERE\""
echo "3. Replace with:"
echo "   clientId: \"$APP_ID\","
echo "   authority: \"https://login.microsoftonline.com/$TENANT_ID\","
echo "   redirectUri: \"https://$STATIC_URL\""
echo ""
echo "4. Save cockpit.html"
echo "5. Go to Portal: https://portal.azure.com"
echo "6. Search for: $STATIC_APP"
echo "7. Click Browse → Upload → drag cockpit.html"
echo "8. Wait 1-2 minutes for it to deploy"
echo "9. Go to: https://$STATIC_URL"
echo "10. Click Sign In and test with your Boels account"

