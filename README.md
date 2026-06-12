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
| `FUNCTION_API_KEY` | Yes | Function host key used for `x-functions-key` header in front-end API calls. Retrieve after first deploy with `az functionapp keys list`. See [Post-deployment setup](#post-deployment-setup). |

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
| `FUNCTION_API_KEY` | Manual (post-deploy) | Function host key retrieved after first deploy and set with `azd env set`. Required for front-end API calls. |

### 3) Compatibility output variables used by scripts when available

| Variable | Used by | What it should be |
|---|---|---|
| `STATIC_WEB_APP_URL` | `scripts/sync-manifest-from-azd.sh` | Full Static Web App URL if present in your environment outputs. |
| `AZURE_STATIC_WEB_APP_URL` | `scripts/sync-manifest-from-azd.sh` | Azure-prefixed variant of Static Web App URL if present. |

Safe defaults used in code generation (non-network):
- Office Add-in ID (GUID): `74f2d75f-6bd1-4bca-9ec0-df5cf006c58a`
- Function runtime: Node.js 20, auth level `function`
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

`app-ui` resolves the function key for the `x-functions-key` header in this order:

1. `VITE_FUNCTION_API_KEY`
2. `FUNCTION_API_KEY`

If no key is set, the header is not sent and authenticated Function endpoints will reject requests.

**`FUNCTION_API_KEY` is required.** After the first `azd up`, retrieve the key and set it:

```bash
# Retrieve the default function key
az functionapp keys list \
  --resource-group "$(azd env get-value AZURE_RESOURCE_GROUP)" \
  --name "$(azd env get-value AZURE_FUNCTION_APP_NAME)" \
  --query "functionKeys.default" -o tsv

# Set it in the azd environment
azd env set FUNCTION_API_KEY <key-from-above>

# Redeploy app-ui so the key is embedded in the build
azd deploy
```

### Security considerations

- `FUNCTION_API_KEY` and `VITE_FUNCTION_API_KEY` are compile-time front-end values.
- If used in `app-ui`, the key is embedded in shipped JavaScript and can be extracted by end users.
- Treat this as a convenience/dev option, not as a strong secret boundary.
- Prefer one of these production patterns:
	- Use a backend proxy that holds the function key server-side.
	- Change the Function endpoint to require Microsoft Entra ID auth and call it with user/app tokens.
	- Keep function-level keys for server-to-server calls only.

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

## Post-deployment setup

After `azd up` succeeds, complete these steps:

### 1) Retrieve and set the Function API key

```bash
# Get the default function key
az functionapp keys list \
  --resource-group "$(azd env get-value AZURE_RESOURCE_GROUP)" \
  --name "$(azd env get-value AZURE_FUNCTION_APP_NAME)" \
  --query "functionKeys.default" -o tsv

# Set it in the azd environment
azd env set FUNCTION_API_KEY <key-from-above>

# Redeploy app-ui so the key is embedded in the client build
azd deploy
```

### 2) Sync the manifest to deployed URLs

```bash
bash scripts/sync-manifest-from-azd.sh
```

> **Windows without bash:** Manually replace all URL hostnames in `app-ui/manifest.xml` with the value of `OFFICE_ADDIN_TASKPANE_URL` from `azd env get-value OFFICE_ADDIN_TASKPANE_URL`.

### 3) Assign Foundry RBAC (if not done during provisioning)

See [Foundry RBAC for the Function managed identity](#foundry-rbac-for-the-function-managed-identity).

## Smoke-test the API

You can test the deployed API without the Word add-in using `curl`.

**Style check:**

```bash
curl -X POST "$(azd env get-value FUNCTION_API_URL)" \
  -H "Content-Type: application/json" \
  -H "x-functions-key: $(azd env get-value FUNCTION_API_KEY)" \
  -d '{"text": "We must utilize the generator and it was decided by the committee."}'
```

**Heartbeat:**

```bash
curl -H "x-functions-key: $(azd env get-value FUNCTION_API_KEY)" \
  "https://$(azd env get-value AZURE_FUNCTION_APP_NAME).azurewebsites.net/api/heartbeat"
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

2. Sync the add-in manifest to deployed URLs:

```bash
bash scripts/sync-manifest-from-azd.sh
```

The script resolves the deployed host from URL outputs first (for example `OFFICE_ADDIN_TASKPANE_URL`) and falls back to Static Web App name only if needed.

You can override this behavior by passing `--host <url>`.

3. Sideload the updated `app-ui/manifest.xml` in Word.
4. Run the same style check flow and verify responses come from the deployed backend.

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

After `azd up`, complete the [Post-deployment setup](#post-deployment-setup) steps:

1. Retrieve and set `FUNCTION_API_KEY`, then redeploy with `azd deploy`.
2. Sync the manifest: `bash scripts/sync-manifest-from-azd.sh`
3. Assign Foundry RBAC if not already configured.
4. Sideload the manifest in Word and test.

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
