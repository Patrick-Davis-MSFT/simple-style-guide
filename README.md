# Style Guide Foundry

Style Guide Foundry is a full-stack Azure solution with:
- `app-ui`: React + Fluent UI Word task pane Office Add-in
- `function`: Azure Function App (Linux) middle-tier API
- `infra`: Bicep-based Azure infrastructure for `azd`
- `scripts`: Deployment helper scripts (validation and RBAC setup)

## Prerequisites

- Node.js 20+
- Azure CLI (`az`) logged in
- Azure Developer CLI (`azd`) logged in
- Office (Word) desktop or web for add-in sideload testing

### Installing Azure Developer CLI (`azd`)

**Windows (winget — recommended):**

```bash
winget install microsoft.azd
```

**Windows (PowerShell — alternative):**

```powershell
powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"
```

**Windows (Chocolatey — alternative):**

```bash
choco install azd
```

> **Note:** After installing, close and reopen your terminal for `azd` to appear on the PATH.

Verify installation:

```bash
azd version
```

### Signing in
You will need both methods to run all scripts

```bash
az login
azd auth login
```

If you are in a terminal without browser access (remote SSH, containers, codespaces):

```bash
azd auth login --use-device-code
```

Both `az login` and `azd auth login` are required — `azd` uses its own auth for deployments, while `az` is used by helper scripts and for `DefaultAzureCredential` locally.

### Windows compatibility note

The `azure.yaml` prepackage hook does **not** use `shell: sh` so it works on Windows without WSL. If you see a `CreateProcessCommon: execvpe(/bin/bash) failed` error, ensure the hook does not include `shell: sh` — it should be:

```yaml
hooks:
  prepackage:
    run: npm run build
```

## Azure Developer CLI (`azd`) environment variables

This project uses three categories of `azd` environment variables:
- **Inputs you set** before `azd provision` / `azd up`
- **Outputs `azd` writes** after infrastructure is provisioned
- **Compatibility outputs** some scripts can consume when present

### 1) Inputs you set with `azd env set`

| Variable | Required | What it should be |
|---|---|---|
| `AZURE_LOCATION` | Yes | Azure region for deployment (for example `eastus2`). |
| `PREFIX` | Yes | Short lowercase name prefix used in resource naming (2-8 chars recommended by infra constraints). |
| `VNET_RESOURCE_ID` | Yes | Full resource ID of an existing VNet used by the Function app integration. Example: `/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<name>`. |
| `AZURE_SUBSCRIPTION_ID` | Optional | Target subscription GUID if you do not want to use the currently selected Azure CLI subscription. |
| `AZURE_EXISTING_AIPROJECT_ENDPOINT` | Optional | Azure AI Foundry project endpoint URL used by Function app settings. |
| `AZURE_EXISTING_AGENT_ID` | Optional | Foundry Agent ID in `name:version` format (for example `agent-plane-talk:2`). |
| `AZURE_FOUNDRY_AGENT_NAME` | Optional | Foundry Agent name when providing agent reference as split values. Use with `AZURE_FOUNDRY_AGENT_VERSION`. |
| `AZURE_FOUNDRY_AGENT_VERSION` | Optional | Foundry Agent version when providing agent reference as split values. Use with `AZURE_FOUNDRY_AGENT_NAME`. |
| `AZURE_EXISTING_AIPROJECT_RESOURCE_ID` | Optional | Full resource ID of the Foundry project. |
| `AZURE_EXISTING_RESOURCE_ID` | Optional | Full resource ID of the Foundry account (used in Function app settings and optional RBAC scope). |
| `AZURE_FOUNDRY_ROLE_DEFINITION_GUID` | Optional | Role definition GUID to assign to Function managed identity at Foundry scope. |
| `AZURE_OPENAI_API_VERSION` | Optional | Preferred API version string for Foundry Azure OpenAI client initialization (for example `2025-11-15-preview`). |
| `OPENAI_API_VERSION` | Optional | API version string for Foundry Azure OpenAI client initialization (for example `2025-03-01-preview`). |

Notes:
- **VNet prerequisite:** `VNET_RESOURCE_ID` must point to an existing VNet. If you do not have one, create it before provisioning (see [Create a VNet](#create-a-vnet-if-needed)).
- You can configure the agent either as `AZURE_EXISTING_AGENT_ID` (`name:version`) or as the split pair `AZURE_FOUNDRY_AGENT_NAME` + `AZURE_FOUNDRY_AGENT_VERSION`.
- `AZURE_OPENAI_API_VERSION` is preferred when both API-version variables are set. `OPENAI_API_VERSION` remains supported for backward compatibility.

### 2) Outputs produced by `azd` (do not manually set in normal flow)

| Variable | Produced from | What it contains |
|---|---|---|
| `AZURE_ENV_NAME` | `azd` environment | Current environment name (for example `style-helper`). |
| `AZURE_RESOURCE_GROUP` | `azd`/provisioning context | Resource group name used for deployment. |
| `RESOURCE_GROUP_ID` | Bicep output | Full resource group resource ID. |
| `AZURE_FUNCTION_APP_NAME` | Bicep output | Function App resource name. |
| `FUNCTION_APP_NAME` | Bicep output (alias) | Same Function App resource name (compat alias). |
| `AZURE_STATIC_WEB_APP_NAME` | Bicep output | Static Web App resource name. |
| `STATIC_WEB_APP_NAME` | Bicep output (alias) | Same Static Web App resource name (compat alias). |
| `AZURE_STORAGE_ACCOUNT_NAME` | Bicep output | Storage account name used by the Function app. |
| `FUNCTION_API_URL` | Bicep output | Deployed style-check endpoint URL, for example `https://<function>.azurewebsites.net/api/style-check`. |
| `OFFICE_ADDIN_TASKPANE_URL` | Bicep output | Deployed task pane host URL, for example `https://<app>.azurestaticapps.net`. |
| `VNET_RESOURCE_ID_ECHO` | Bicep output | Echo of the VNet resource ID passed at deploy time (for troubleshooting/verification). |

### 3) Compatibility output variables used by scripts when available

| Variable | Used by | What it should be |
|---|---|---|
| `STATIC_WEB_APP_URL` | `scripts/sync-manifest-from-azd.sh` | Full Static Web App URL if present in your environment outputs. |
| `AZURE_STATIC_WEB_APP_URL` | `scripts/sync-manifest-from-azd.sh` | Azure-prefixed variant of Static Web App URL if present. |

Safe defaults used in code generation (non-network):
- Office Add-in ID (GUID): `74f2d75f-6bd1-4bca-9ec0-df5cf006c58a`
- Function runtime: Node.js 20
- App UI framework: React + Fluent UI

## App UI environment variables

`app-ui` resolves the style-check endpoint in this order:

1. **Runtime config** (`/api/config` endpoint served by `server.js`) — returns the `STYLE_CHECK_API_URL` Web App app setting
2. `VITE_FUNCTION_BASE_URL` (build-time fallback, used as `<base>/api/style-check`)
3. `FUNCTION_API_URL` (used as-is)
4. Fallback: `/api/style-check`

Notes:
- In Azure Government (VNet mode), the function URL is resolved at **runtime** from the `/api/config` endpoint. This allows changing the URL via the Web App app setting (`STYLE_CHECK_API_URL`) without rebuilding the UI.
- `VITE_FUNCTION_BASE_URL` is intended for local/front-end-specific builds.
- `FUNCTION_API_URL` is produced by `azd` environment outputs and is available during deploy builds.
- Vite variables are compile-time values, so any change requires rebuilding/redeploying `app-ui`.

### Function authentication model

This deployment assumes Azure App Service Authentication / Authorization (Easy Auth) is enabled on the Function App.

- Function endpoints are expected to be protected by Easy Auth (Microsoft Entra ID), not by Function host keys.
- `FUNCTION_API_KEY` and `VITE_FUNCTION_API_KEY` are not required in this deployment flow.
- Requests from the Office add-in should authenticate through Easy Auth (for example, bearer token/cookie-backed session), not `x-functions-key`.

⚠️ 🔒 **Security warning for secured environments:**
In a secured production environment, you must enable and enforce Easy Auth on both surfaces to fully secure this solution:
- Web application host used by the add-in (for example Static Web App/App Service front end)
- Function App API backend

✅ **Minimum secure baseline:**
- Require authentication for unauthenticated requests
- Use Microsoft Entra ID as the identity provider
- Verify both front-end and API routes are protected before go-live

### Create a VNet (if needed)

The `VNET_RESOURCE_ID` parameter must reference an existing Azure Virtual Network. If your resource group does not already contain one, create it first:

```bash
az network vnet create \
  --name styleguide-vnet \
  --resource-group <your-resource-group> \
  --location <your-region> \
  --address-prefix 10.0.0.0/16 \
  --subnet-name default \
  --subnet-prefix 10.0.0.0/24
```

Retrieve the full resource ID:

```bash
az network vnet show \
  --name styleguide-vnet \
  --resource-group <your-resource-group> \
  --query id -o tsv
```

### Set values before provision/deploy

```bash
azd env new dev
azd env set AZURE_LOCATION <your-region>
azd env set PREFIX <your-prefix>
azd env set VNET_RESOURCE_ID <vnet-resource-id-from-above>
# optional
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_EXISTING_AIPROJECT_ENDPOINT <foundry-project-endpoint>
azd env set AZURE_EXISTING_AIPROJECT_RESOURCE_ID <foundry-project-resource-id>
azd env set AZURE_EXISTING_RESOURCE_ID <foundry-account-resource-id>
azd env set AZURE_EXISTING_AGENT_ID <agent-name:version>
# or split agent configuration
azd env set AZURE_FOUNDRY_AGENT_NAME <agent-name>
azd env set AZURE_FOUNDRY_AGENT_VERSION <agent-version>
azd env set AZURE_OPENAI_API_VERSION 2025-11-15-preview
# backward-compatible alias still supported
azd env set OPENAI_API_VERSION 2025-03-01-preview

# validate required values are present
bash scripts/validate-env.sh
```

### Foundry RBAC for the Function managed identity

After `azd up`, the Function App's system-assigned managed identity needs permission to call the Azure AI Foundry agent. If you did not set `AZURE_EXISTING_RESOURCE_ID` + `AZURE_FOUNDRY_ROLE_DEFINITION_GUID` before provisioning, assign the role manually:

```bash
# Get the Function App's managed identity principal ID
principal_id=$(az functionapp identity show \
  --name "$(azd env get-value AZURE_FUNCTION_APP_NAME)" \
  --resource-group "$(azd env get-value AZURE_RESOURCE_GROUP)" \
  --query principalId -o tsv)

# Assign Cognitive Services User on the Foundry account
az role assignment create \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services User" \
  --scope <foundry-account-resource-id>
```

Alternatively, set these env vars and re-provision to let Bicep handle it:

```bash
azd env set AZURE_EXISTING_RESOURCE_ID <foundry-account-resource-id>
azd env set AZURE_FOUNDRY_ROLE_DEFINITION_GUID 5e0bd9bd-7b93-4f28-af87-19fc36ad61bd
azd provision
```

> The GUID `5e0bd9bd-7b93-4f28-af87-19fc36ad61bd` is the **Cognitive Services User** role. Use `a97b65f3-24c7-4388-baec-2e87135dc908` for **Cognitive Services OpenAI User** if your Foundry setup requires it.

## Local development

### 1) Function API

```bash
cd function
npm install
npm run build
npm run start
```

`style-check` now uses an Azure AI Foundry Agent via `DefaultAzureCredential`:
- Local: uses the signed-in developer identity (`az login`).
- Azure Function App: uses the app's system-assigned managed identity.

Set these in `function/local.settings.json` for local runs:
- `AZURE_EXISTING_AIPROJECT_ENDPOINT`
- `AZURE_EXISTING_AGENT_ID` (format: `name:version`, for example `agent-plane-talk:2`) **or** `AZURE_FOUNDRY_AGENT_NAME` + `AZURE_FOUNDRY_AGENT_VERSION`
- `AZURE_OPENAI_API_VERSION` (preferred, for example `2025-11-15-preview`) or `OPENAI_API_VERSION` (backward-compatible alias)

The local function endpoint is typically:
- `http://localhost:7071/api/style-check`
- `http://localhost:7071/api/heartbeat`

For heartbeat Cosmos connectivity checks, set `COSMOS_ENDPOINT` (or `COSMOS_DB_ENDPOINT`) in `function/local.settings.json`.

### 2) App UI (Office Add-in task pane)

```bash
cd app-ui
npm install
npm run dev
```

Then sideload `app-ui/manifest.xml` into Word. During local dev, update the manifest `SourceLocation` host to your local HTTPS dev URL (for example `https://localhost:3000/taskpane.html`).

To reset all manifest add-in URLs back to local dev in one step:

```bash
bash scripts/sync-manifest-from-azd.sh --localhost
```

To force all manifest URLs to a specific host:

```bash
bash scripts/sync-manifest-from-azd.sh --host https://my-host.example.com
```

### Sideload the add-in

Use this process whenever you need to load or reload the manifest in Word.

1. Make sure `app-ui/manifest.xml` points to the correct `SourceLocation` URL:
	- Local dev: your local HTTPS Vite URL (for example `https://localhost:3000/taskpane.html`)
	- Deployed: your Static Web App URL (use `bash scripts/sync-manifest-from-azd.sh` after `azd up`)

`scripts/sync-manifest-from-azd.sh` now rewrites all manifest URLs that target either localhost or Azure Static Web Apps on every run.

#### Word on the web

1. Open Word in the browser and open any document.
2. Go to **Insert** → **Add-ins** → **My Add-ins**.
3. Choose **Upload My Add-in**.
4. Select `app-ui/manifest.xml`.
5. Open the add-in from **My Add-ins** to launch the task pane.

#### Word desktop (Microsoft 365)

1. Open Word desktop and open any document.
2. Go to **Insert** → **My Add-ins**.
3. Open the **Shared Folder** tab (or equivalent upload option in your build).
4. Add/select `app-ui/manifest.xml`.
5. Open the add-in to launch the task pane.

If Word has a cached older manifest, remove the add-in and sideload it again.

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

If values are not already present in your `azd` environment, the script prompts for them.

### Step 3: Run `scripts/sync-manifest-from-azd.sh`

Sync Office add-in URLs in the manifest to the deployed host:

```bash
bash scripts/sync-manifest-from-azd.sh
```

> **Windows without bash:** manually replace all URL hostnames in `app-ui/manifest.xml` with the value from `azd env get-value OFFICE_ADDIN_TASKPANE_URL`.

### Step 4: Configure Easy Auth authentication

Enable and configure Authentication/Authorization (Easy Auth) on the Function App.

1. Open Azure Portal -> Function App -> Authentication.
2. Enable Authentication.
3. Add Microsoft identity provider (Microsoft Entra ID).
4. Set unauthenticated requests to require authentication.
5. Save configuration and verify sign-in flow works for your app.

This project assumes Easy Auth is the protection boundary for Function endpoints.

### Step 5: Upload manifest `app-ui/manifest.xml`

Upload the updated manifest in Word:

1. Open Word (web or desktop) and open a document.
2. Go to Insert -> Add-ins / My Add-ins.
3. Choose Upload My Add-in.
4. Select `app-ui/manifest.xml`.
5. Launch the task pane and verify calls succeed.

If Word still uses an older manifest, remove the add-in and upload again.

## Environment variables to set

Set these before deployment and post-deployment scripts:

### Required

```bash
azd env set AZURE_LOCATION <region>
azd env set PREFIX <prefix>
azd env set VNET_RESOURCE_ID <vnet-resource-id>
```

### Required for Foundry/Function integration

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

### Optional

```bash
azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
azd env set AZURE_EXISTING_AIPROJECT_RESOURCE_ID <foundry-project-resource-id>
azd env set AZURE_EXISTING_RESOURCE_ID <foundry-account-resource-id>
azd env set AZURE_FOUNDRY_ROLE_DEFINITION_GUID <role-guid>
azd env set AZURE_OPENAI_API_VERSION 2025-11-15-preview
azd env set OPENAI_API_VERSION 2025-03-01-preview
```

No Function key variables are required for this flow.

## Smoke-test the API

You can test the deployed API without the Word add-in using `curl`.

**Style check:**

```bash
curl -X POST "$(azd env get-value FUNCTION_API_URL)" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <entra-access-token>" \
  -d '{"text": "We must utilize the generator and it was decided by the committee."}'
```

**Heartbeat:**

```bash
curl -H "Authorization: Bearer <entra-access-token>" \
  "https://$(azd env get-value AZURE_FUNCTION_APP_NAME).azurewebsites.net/api/heartbeat"
```

Token example:

```bash
az account get-access-token --resource api://<your-function-app-client-id> --query accessToken -o tsv
```

Expected style-check response: a JSON object with `issues` and `replacements` arrays containing style-guide corrections (for example, "utilize" → "use", passive voice flagged).

If you get a `403` or a message about missing `data action`, see [Foundry RBAC for the Function managed identity](#foundry-rbac-for-the-function-managed-identity).

## Test the Word add-in

### Local end-to-end test

1. Start the Function API:

```bash
cd function
npm install
npm run build
npm run start
```

2. Start the app UI:

```bash
cd app-ui
npm install
npm run dev
```

3. Ensure `app-ui/manifest.xml` points `SourceLocation` to your local HTTPS task pane URL (for example `https://localhost:3000/taskpane.html`).
4. Sideload `app-ui/manifest.xml` in Word (desktop or web).
5. Open a document, launch the add-in task pane, and submit sample text for style checking.
6. Confirm the UI receives a response and suggestions from the Function API.

### Deployed environment test

1. Deploy infrastructure and app:

```bash
azd up
```

2. Configure Foundry agent and Function settings:

```bash
bash scripts/configure-foundry-agent-and-function-settings.sh
```

3. Sync the add-in manifest to deployed URLs:

```bash
bash scripts/sync-manifest-from-azd.sh
```

The script resolves the deployed host from URL outputs first (for example `OFFICE_ADDIN_TASKPANE_URL`) and falls back to Static Web App name only if needed.

You can override this behavior by passing `--host <url>`.

4. Configure Easy Auth in Azure Portal (Function App -> Authentication).
5. Sideload the updated `app-ui/manifest.xml` in Word.
6. Run the same style check flow and verify responses come from the deployed backend.

### Troubleshooting checklist

- Verify local Function is running at `http://localhost:7071/api/style-check`.
- Verify the manifest `SourceLocation` exactly matches the active UI host URL.
- If sideload fails, remove the add-in and sideload the manifest again.
- If API calls fail, check Function logs in the terminal for errors.

## Azure deployment

Preview first:

```bash
azd provision --preview
```

Provision + deploy:

```bash
azd up
```

Outputs include the Function App URL and Static Web App URL.

After `azd up`, complete the [Deployment steps (recommended)](#deployment-steps-recommended) sequence.

## Scripts

- `scripts/validate-env.sh`: checks required `azd` env vars exist
- `scripts/assign-function-storage-rbac.sh`: assigns storage data-plane role to Function managed identity
- `scripts/ping-heartbeat.sh`: sends an authenticated heartbeat request (local or deployed)

Run validation:

```bash
bash scripts/validate-env.sh
```

Authenticated heartbeat ping examples:

```bash
# explicit URL + key
bash scripts/ping-heartbeat.sh http://localhost:7071/api/heartbeat <function-key>

# use environment variables
HEARTBEAT_URL=http://localhost:7071/api/heartbeat FUNCTION_KEY=<function-key> bash scripts/ping-heartbeat.sh

# deployed app: auto-resolve URL and key from azd/az
RESOLVE_FROM_AZD=true bash scripts/ping-heartbeat.sh
```

## Optional Azure CLI operations

Preview with Azure CLI what-if at resource-group scope (after `azd provision` creates the RG):

```bash
az deployment group what-if \
	--resource-group "$(azd env get-value AZURE_RESOURCE_GROUP)" \
	--template-file infra/main.bicep \
	--parameters @infra/main.parameters.json
```
