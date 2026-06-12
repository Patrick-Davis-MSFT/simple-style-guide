# Deployment Guide — Style Guide Foundry

This document walks through the end-to-end steps to deploy Style Guide Foundry to Azure using `azd`, including infrastructure provisioning, post-deploy configuration, and redeploying the UI after environment changes.

---

## Prerequisites

1. **Node.js 20+** installed.
2. **Azure CLI** installed and signed in:

   ```bash
   az login
   ```

3. **Azure Developer CLI (`azd`)** installed and signed in:

   ```bash
   winget install microsoft.azd
   azd auth login
   ```

   > After installing, close and reopen your terminal for `azd` to appear on the PATH.
   >
   > If you are in a terminal without browser access, use `azd auth login --use-device-code`.

4. An **Azure subscription** with permissions to create resources.
5. An **Azure resource group** (for example `nkidambi-styleguide`).

---

## Step 1 — Create a VNet (if needed)

The deployment requires an existing Azure Virtual Network. If your resource group does not already contain one:

```bash
az network vnet create ^
  --name styleguide-vnet ^
  --resource-group nkidambi-styleguide ^
  --location eastus2 ^
  --address-prefix 10.0.0.0/16 ^
  --subnet-name default ^
  --subnet-prefix 10.0.0.0/24
```

Retrieve the full resource ID:

```bash
az network vnet show ^
  --name styleguide-vnet ^
  --resource-group nkidambi-styleguide ^
  --query id -o tsv
```

Save this value — you will need it in the next step.

---

## Step 2 — Create and configure the `azd` environment

```bash
azd env new <your-env-name>
```

Set the required variables:

```bash
azd env set AZURE_LOCATION eastus2
azd env set PREFIX stylegdl
azd env set VNET_RESOURCE_ID /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>
```

Set optional variables (Foundry agent, subscription, etc.):

```bash
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_EXISTING_AIPROJECT_ENDPOINT <foundry-project-endpoint>
azd env set AZURE_EXISTING_AGENT_ID <agent-name:version>
azd env set AZURE_OPENAI_API_VERSION 2025-11-15-preview
```

Validate that required values are present:

```bash
bash scripts/validate-env.sh
```

---

## Step 3 — Provision and deploy with `azd up`

This single command provisions all Azure infrastructure (via Bicep) and deploys both the Function App and Static Web App:

```bash
azd up
```

### What `azd up` creates

| Resource | Purpose |
|----------|---------|
| Storage Account | Function App backing storage (managed identity auth) |
| Log Analytics Workspace | Centralized logging |
| Application Insights | Function App monitoring |
| App Service Plan (EP1) | Elastic Premium plan for Functions |
| Function App (Linux, Node 22) | Middle-tier API (`/api/style-check`, `/api/heartbeat`) |
| Static Web App (Free) | Hosts the React + Fluent UI Office Add-in task pane |
| RBAC Role Assignments | Storage, App Insights, and optionally Foundry roles |

### Windows note

If you see a `CreateProcessCommon: execvpe(/bin/bash) failed` error, ensure `azure.yaml` does **not** include `shell: sh` in the prepackage hook. It should be:

```yaml
hooks:
  prepackage:
    run: npm run build
```

---

## Step 4 — Retrieve and set the Function API key

After the first `azd up`, a Function host key is generated. The `app-ui` front end needs this key to call the Function API.

**Retrieve the key:**

```bash
az functionapp keys list ^
  --resource-group nkidambi-styleguide ^
  --name <your-function-app-name> ^
  --query "functionKeys.default" -o tsv
```

> Replace `<your-function-app-name>` with the value from `azd env get-value AZURE_FUNCTION_APP_NAME`.

**Set it in the `azd` environment:**

```bash
azd env set FUNCTION_API_KEY <key-from-above>
```

---

## Step 5 — Redeploy the UI with the updated environment

After setting `FUNCTION_API_KEY`, redeploy so the key is embedded in the client build:

```bash
azd deploy
```

This rebuilds `app-ui` (which reads `FUNCTION_API_KEY` at Vite compile time) and redeploys both services. Without this step, the front end will not send the `x-functions-key` header and API calls will fail with `401`.

---

## Step 6 — Sync the add-in manifest

Update `app-ui/manifest.xml` with the deployed Static Web App URLs:

**With bash available (Git Bash, WSL, Linux, macOS):**

```bash
bash scripts/sync-manifest-from-azd.sh
```

**Without bash (Windows cmd/PowerShell):**

Get the deployed URL:

```bash
azd env get-value OFFICE_ADDIN_TASKPANE_URL
```

Then manually find-and-replace all URL hostnames in `app-ui/manifest.xml` with that value.

---

## Step 7 — Assign Foundry RBAC (if needed)

If the Function App's managed identity does not have permission to call the Azure AI Foundry agent, you will get an error like:

> `The principal ... lacks the required data action Microsoft.CognitiveServices/accounts/AIServices/agents/write`

**Option A — Manual role assignment:**

```bash
az functionapp identity show ^
  --name <your-function-app-name> ^
  --resource-group nkidambi-styleguide ^
  --query principalId -o tsv
```

```bash
az role assignment create ^
  --assignee-object-id <principal-id> ^
  --assignee-principal-type ServicePrincipal ^
  --role "Cognitive Services User" ^
  --scope <foundry-account-resource-id>
```

**Option B — Let Bicep handle it on next provision:**

```bash
azd env set AZURE_EXISTING_RESOURCE_ID <foundry-account-resource-id>
azd env set AZURE_FOUNDRY_ROLE_DEFINITION_GUID 5e0bd9bd-7b93-4f28-af87-19fc36ad61bd
azd provision
```

---

## Step 8 — Smoke-test the API

Test the deployed endpoints without the Word add-in:

**Style check:**

```bash
curl -X POST https://<function-app-name>.azurewebsites.net/api/style-check ^
  -H "Content-Type: application/json" ^
  -H "x-functions-key: <your-function-key>" ^
  -d "{\"text\": \"We must utilize the generator and it was decided by the committee.\"}"
```

**Heartbeat:**

```bash
curl -H "x-functions-key: <your-function-key>" ^
  https://<function-app-name>.azurewebsites.net/api/heartbeat
```

Expected: style-check returns a JSON object with `issues` and `replacements` arrays containing style-guide corrections.

---

## Step 9 — Sideload the add-in in Word

### Word on the web

1. Open Word in the browser → open any document.
2. **Insert** → **Add-ins** → **My Add-ins** → **Upload My Add-in**.
3. Select `app-ui/manifest.xml`.
4. Open the add-in from **My Add-ins** to launch the task pane.

### Word desktop (Microsoft 365)

1. Open Word desktop → open any document.
2. **Insert** → **My Add-ins**.
3. Upload/select `app-ui/manifest.xml`.
4. Click **Open Style Guide** on the Home tab.

---

## Quick reference — Environment file

After a successful deployment, your `.azure/<env-name>/.env` will look similar to:

```ini
AZURE_ENV_NAME="nkidambi-dev"
AZURE_FUNCTION_APP_NAME="azfuncstylegdlpkizw2d"
AZURE_LOCATION="eastus2"
AZURE_RESOURCE_GROUP="nkidambi-styleguide"
AZURE_STATIC_WEB_APP_NAME="azswastylegdlpkizw2d"
AZURE_STORAGE_ACCOUNT_NAME="azststylegdlpkizw2dzx"
AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
FUNCTION_API_URL="https://azfuncstylegdlpkizw2d.azurewebsites.net/api/style-check"
FUNCTION_APP_NAME="azfuncstylegdlpkizw2d"
FUNCTION_API_KEY="<your-function-key>"
OFFICE_ADDIN_TASKPANE_URL="https://salmon-plant-0a7e52e0f.6.azurestaticapps.net"
RESOURCE_GROUP_ID="/subscriptions/<sub>/resourceGroups/nkidambi-styleguide"
STATIC_WEB_APP_NAME="azswastylegdlpkizw2d"
VNET_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/nkidambi-styleguide/providers/Microsoft.Network/virtualNetworks/styleguide-vnet"
```

`FUNCTION_API_KEY` is the only value you set manually after the first `azd up`. All other values are either inputs you set before provisioning or outputs produced by the Bicep deployment.

---

## Redeployment cheat sheet

| Scenario | Command |
|----------|---------|
| Full infra + code deploy | `azd up` |
| Redeploy code only (after env change) | `azd deploy` |
| Re-provision infra only | `azd provision` |
| Preview infra changes | `azd provision --preview` |
| Sync manifest to deployed URLs | `bash scripts/sync-manifest-from-azd.sh` |
| Sync manifest to localhost | `bash scripts/sync-manifest-from-azd.sh --localhost` |
| Validate env vars | `bash scripts/validate-env.sh` |

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `execvpe(/bin/bash) failed` during `azd up` | `azure.yaml` has `shell: sh` | Remove `shell: sh` from the prepackage hook |
| `vnetSubscriptionId` index out of bounds | `VNET_RESOURCE_ID` is empty or malformed | Set the full VNet resource ID with `azd env set VNET_RESOURCE_ID ...` |
| `401 Unauthorized` on API calls | Missing `x-functions-key` header | Set `FUNCTION_API_KEY` and redeploy with `azd deploy` |
| `403` / `lacks required data action` | Function identity missing Foundry RBAC | Assign **Cognitive Services User** role (see Step 7) |
| Manifest sideload shows old UI | Word cached old manifest | Remove the add-in and re-sideload `manifest.xml` |
| `azd` not recognized | PATH not refreshed after install | Close and reopen the terminal |
