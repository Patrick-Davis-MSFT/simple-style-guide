# Deployment Guide - Style Guide Foundry

This document is aligned with the project deployment model in README and uses Easy Auth as the Function API protection boundary.

## Prerequisites

1. Node.js 20+ installed.
2. Azure CLI installed and signed in.

```bash
az login
```

3. Azure Developer CLI (azd) installed and signed in.

```bash
azd auth login
```

If you are in a terminal without browser access:

```bash
azd auth login --use-device-code
```

4. Azure subscription with permissions to create resources.
5. Existing Azure Virtual Network resource ID for `VNET_RESOURCE_ID`.

## Deployment steps (recommended)

Use this deployment order:

1. `azd up`
2. `scripts/configure-foundry-agent-and-function-settings.sh`
3. `scripts/sync-manifest-from-azd.sh`
4. Configure Easy Auth authentication
5. Upload manifest `app-ui/manifest.xml`

### Step 1: Run `azd up`

Provision infrastructure and deploy app components:

```bash
azd up
```

This creates/updates the Function App, Static Web App, identity/RBAC wiring, and supporting resources.

### Step 2: Run `scripts/configure-foundry-agent-and-function-settings.sh`

Create/update the Foundry agent and apply required app settings locally and in Azure Function App:

```bash
bash scripts/configure-foundry-agent-and-function-settings.sh
```

If values are not already present in your azd environment, the script prompts for them.

### Step 3: Run `scripts/sync-manifest-from-azd.sh`

Sync Office add-in URLs in the manifest to the deployed host:

```bash
bash scripts/sync-manifest-from-azd.sh
```

Windows without bash:
Manually replace all URL hostnames in `app-ui/manifest.xml` with the value from:

```bash
azd env get-value OFFICE_ADDIN_TASKPANE_URL
```

### Step 4: Configure Easy Auth authentication

Enable and configure Authentication/Authorization (Easy Auth) on the Function App.

1. Open Azure Portal -> Function App -> Authentication.
2. Enable Authentication.
3. Add Microsoft identity provider (Microsoft Entra ID).
4. Set unauthenticated requests to require authentication.
5. Save configuration and verify sign-in flow works for your app.

Function authentication assumption:

- Function endpoints are protected by Easy Auth (Microsoft Entra ID), not by Function host keys.
- `FUNCTION_API_KEY` and `VITE_FUNCTION_API_KEY` are not required for this deployment flow.
- Office add-in requests should authenticate through Easy Auth (bearer token or cookie-backed session), not `x-functions-key`.

⚠️ 🔒 **Security warning for secured environments:**
In a secured production environment, you must enable and enforce Easy Auth on both surfaces to fully secure this solution:
- Web application host used by the add-in (for example Static Web App/App Service front end)
- Function App API backend

✅ **Minimum secure baseline:**
- Require authentication for unauthenticated requests
- Use Microsoft Entra ID as the identity provider
- Verify both front-end and API routes are protected before go-live

### Step 5: Upload manifest `app-ui/manifest.xml`

Upload the updated manifest in Word.

Word on the web:

1. Open Word in the browser and open any document.
2. Go to Insert -> Add-ins -> My Add-ins.
3. Choose Upload My Add-in.
4. Select `app-ui/manifest.xml`.
5. Open the add-in from My Add-ins to launch the task pane.

Word desktop (Microsoft 365):

1. Open Word desktop and open any document.
2. Go to Insert -> My Add-ins.
3. Upload/select `app-ui/manifest.xml`.
4. Open the add-in to launch the task pane.

If Word still uses an older manifest, remove the add-in and upload again.

## Environment variables to set

Set these before deployment and post-deployment scripts.

Required:

```bash
azd env set AZURE_LOCATION <region>
azd env set PREFIX <prefix>
azd env set VNET_RESOURCE_ID <vnet-resource-id>
```

Required for Foundry/Function integration:

```bash
azd env set AZURE_EXISTING_AIPROJECT_ENDPOINT <foundry-project-endpoint>
```

Set one of these agent configurations:

```bash
# Option A: single id
azd env set AZURE_EXISTING_AGENT_ID <agent-name:version>

# Option B: split values
azd env set AZURE_FOUNDRY_AGENT_NAME <agent-name>
azd env set AZURE_FOUNDRY_AGENT_VERSION <agent-version>
```

Optional:

```bash
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_EXISTING_AIPROJECT_RESOURCE_ID <foundry-project-resource-id>
azd env set AZURE_EXISTING_RESOURCE_ID <foundry-account-resource-id>
azd env set AZURE_FOUNDRY_ROLE_DEFINITION_GUID <role-guid>
azd env set AZURE_OPENAI_API_VERSION 2025-11-15-preview
azd env set OPENAI_API_VERSION 2025-03-01-preview
```

No Function key variables are required for this flow.

## Foundry RBAC for the Function managed identity

After `azd up`, the Function App system-assigned managed identity needs permission to call the Azure AI Foundry agent.

Manual assignment:

```bash
principal_id=$(az functionapp identity show \
  --name "$(azd env get-value AZURE_FUNCTION_APP_NAME)" \
  --resource-group "$(azd env get-value AZURE_RESOURCE_GROUP)" \
  --query principalId -o tsv)

az role assignment create \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services User" \
  --scope <foundry-account-resource-id>
```

Or set env vars and re-provision with Bicep:

```bash
azd env set AZURE_EXISTING_RESOURCE_ID <foundry-account-resource-id>
azd env set AZURE_FOUNDRY_ROLE_DEFINITION_GUID 5e0bd9bd-7b93-4f28-af87-19fc36ad61bd
azd provision
```

## Smoke-test the API

Style check:

```bash
curl -X POST "$(azd env get-value FUNCTION_API_URL)" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <entra-access-token>" \
  -d '{"text": "We must utilize the generator and it was decided by the committee."}'
```

Heartbeat:

```bash
curl -H "Authorization: Bearer <entra-access-token>" \
  "https://$(azd env get-value AZURE_FUNCTION_APP_NAME).azurewebsites.net/api/heartbeat"
```

Token example:

```bash
az account get-access-token --resource api://<your-function-app-client-id> --query accessToken -o tsv
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `execvpe(/bin/bash) failed` during `azd up` | `azure.yaml` has `shell: sh` | Remove `shell: sh` from the prepackage hook |
| `vnetSubscriptionId` index out of bounds | `VNET_RESOURCE_ID` is empty or malformed | Set full VNet resource ID with `azd env set VNET_RESOURCE_ID ...` |
| `401` or auth challenges on API calls | Easy Auth token/session missing | Sign in via configured Entra flow and send a valid bearer token/session |
| `403` or `lacks required data action` | Function identity missing Foundry RBAC | Assign Cognitive Services User role |
| Manifest sideload shows old UI | Word cached old manifest | Remove add-in and re-upload `app-ui/manifest.xml` |
| `azd` not recognized | PATH not refreshed after install | Close and reopen terminal |
