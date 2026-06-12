#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/create-foundry-agent-and-sync-settings.sh \
    [--project-endpoint <https://.../api/projects/...>] \
    [--agent-yaml <path>] \
    [--resource-group <name>] \
    [--function-app <name>]

What this script does:
1) Creates/updates a Foundry agent from a YAML definition.
2) Updates Function settings in:
   - function/local.settings.json (creates from local.settings.json.example if missing)
   - Azure Function App app settings

Behavior notes:
- Uses azd env values when available.
- Prompts for missing values.
- If YAML agent id differs from azd env AZURE_EXISTING_AGENT_ID, the azd env value is used.
- Uses az login / Azure CLI token for Foundry authentication.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

strip_wrapping_quotes() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  printf '%s' "$value"
}

parse_agent_id() {
  local agent_id="$1"
  if [[ "$agent_id" == *:* ]]; then
    local name_part version_part
    name_part="${agent_id%:*}"
    version_part="${agent_id##*:}"
    if [[ -n "$name_part" && -n "$version_part" ]]; then
      printf '%s\n%s\n' "$name_part" "$version_part"
      return 0
    fi
  fi
  return 1
}

azd_env_get() {
  local key="$1"
  if command -v azd >/dev/null 2>&1; then
    azd env get-value "$key" 2>/dev/null || true
  fi
}

prompt_if_empty() {
  local var_name="$1"
  local prompt_text="$2"
  local current_value="$3"
  if [[ -n "$current_value" ]]; then
    printf '%s' "$current_value"
    return 0
  fi

  local entered=""
  while [[ -z "$entered" ]]; do
    read -r -p "$prompt_text" entered
  done
  printf '%s' "$entered"
}

extract_yaml_scalar() {
  local file_path="$1"
  local regex="$2"
  sed -nE "s/${regex}/\\1/p" "$file_path" | head -n1
}

extract_yaml_block_instructions() {
  local file_path="$1"
  awk '
    /^  instructions:[[:space:]]*\|-/ { in_block=1; next }
    in_block {
      if ($0 ~ /^  [A-Za-z0-9_.-]+:[[:space:]]*/) {
        exit
      }
      if ($0 ~ /^    /) {
        print substr($0, 5)
        next
      }
      if ($0 ~ /^$/) {
        print ""
        next
      }
      exit
    }
  ' "$file_path"
}

curl_json() {
  local method="$1"
  local url="$2"
  local token="$3"
  local body_file="$4"
  local output_file="$5"

  local http_code
  if [[ -n "$body_file" ]]; then
    http_code="$(curl -sS -o "$output_file" -w '%{http_code}' -X "$method" "$url" \
      -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json' \
      --data-binary "@$body_file")"
  else
    http_code="$(curl -sS -o "$output_file" -w '%{http_code}' -X "$method" "$url" \
      -H "Authorization: Bearer $token" \
      -H 'Accept: application/json')"
  fi

  printf '%s' "$http_code"
}

PROJECT_ENDPOINT=""
AGENT_YAML_PATH="agents/styleGuide.yaml"
RESOURCE_GROUP=""
FUNCTION_APP_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-endpoint)
      PROJECT_ENDPOINT="${2:-}"
      shift 2
      ;;
    --agent-yaml)
      AGENT_YAML_PATH="${2:-}"
      shift 2
      ;;
    --resource-group)
      RESOURCE_GROUP="${2:-}"
      shift 2
      ;;
    --function-app)
      FUNCTION_APP_NAME="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd az
require_cmd jq
require_cmd curl

if [[ ! -f "$AGENT_YAML_PATH" ]]; then
  echo "Agent YAML not found: $AGENT_YAML_PATH" >&2
  exit 1
fi

# Prefer values from azd environment when available.
if [[ -z "$PROJECT_ENDPOINT" ]]; then
  PROJECT_ENDPOINT="$(azd_env_get AZURE_EXISTING_AIPROJECT_ENDPOINT)"
fi
if [[ -z "$RESOURCE_GROUP" ]]; then
  RESOURCE_GROUP="$(azd_env_get AZURE_RESOURCE_GROUP)"
fi
if [[ -z "$FUNCTION_APP_NAME" ]]; then
  FUNCTION_APP_NAME="$(azd_env_get AZURE_FUNCTION_APP_NAME)"
  if [[ -z "$FUNCTION_APP_NAME" ]]; then
    FUNCTION_APP_NAME="$(azd_env_get FUNCTION_APP_NAME)"
  fi
fi

PROJECT_ENDPOINT="$(strip_wrapping_quotes "$PROJECT_ENDPOINT")"
RESOURCE_GROUP="$(strip_wrapping_quotes "$RESOURCE_GROUP")"
FUNCTION_APP_NAME="$(strip_wrapping_quotes "$FUNCTION_APP_NAME")"

PROJECT_ENDPOINT="$(prompt_if_empty "PROJECT_ENDPOINT" "Foundry Project Endpoint (https://.../api/projects/...): " "$PROJECT_ENDPOINT")"
RESOURCE_GROUP="$(prompt_if_empty "RESOURCE_GROUP" "Azure Resource Group for Function App: " "$RESOURCE_GROUP")"
FUNCTION_APP_NAME="$(prompt_if_empty "FUNCTION_APP_NAME" "Azure Function App name: " "$FUNCTION_APP_NAME")"

# Normalize endpoint
PROJECT_ENDPOINT="${PROJECT_ENDPOINT%/}"

if [[ "$PROJECT_ENDPOINT" != https://*"/api/projects/"* ]]; then
  echo "Project endpoint does not look like a Foundry project endpoint: $PROJECT_ENDPOINT" >&2
  exit 1
fi

# Validate/login with Azure CLI
if ! az account show >/dev/null 2>&1; then
  echo "No active Azure CLI login found. Running az login..."
  az login >/dev/null
fi

subscription_id="$(azd_env_get AZURE_SUBSCRIPTION_ID)"
subscription_id="$(strip_wrapping_quotes "$subscription_id")"
if [[ -n "$subscription_id" ]]; then
  az account set --subscription "$subscription_id"
fi

# Read YAML values.
yaml_agent_id="$(extract_yaml_scalar "$AGENT_YAML_PATH" '^[[:space:]]*id:[[:space:]]*([^[:space:]].*)$')"
yaml_agent_name="$(extract_yaml_scalar "$AGENT_YAML_PATH" '^[[:space:]]*name:[[:space:]]*([^[:space:]].*)$')"
yaml_agent_version="$(extract_yaml_scalar "$AGENT_YAML_PATH" '^[[:space:]]*version:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$')"
yaml_description="$(extract_yaml_scalar "$AGENT_YAML_PATH" '^[[:space:]]*description:[[:space:]]*"?(.*)"?[[:space:]]*$')"
yaml_kind="$(extract_yaml_scalar "$AGENT_YAML_PATH" '^  kind:[[:space:]]*([^[:space:]].*)$')"
yaml_model="$(extract_yaml_scalar "$AGENT_YAML_PATH" '^  model:[[:space:]]*([^[:space:]].*)$')"
yaml_tools_inline="$(extract_yaml_scalar "$AGENT_YAML_PATH" '^  tools:[[:space:]]*(.*)$')"
yaml_instructions="$(extract_yaml_block_instructions "$AGENT_YAML_PATH")"

yaml_agent_id="$(strip_wrapping_quotes "$yaml_agent_id")"
yaml_agent_name="$(strip_wrapping_quotes "$yaml_agent_name")"
yaml_agent_version="$(strip_wrapping_quotes "$yaml_agent_version")"
yaml_kind="$(strip_wrapping_quotes "$yaml_kind")"
yaml_model="$(strip_wrapping_quotes "$yaml_model")"

if [[ -z "$yaml_kind" ]]; then
  yaml_kind="prompt"
fi

if [[ -z "$yaml_model" ]]; then
  echo "Missing definition.model in $AGENT_YAML_PATH" >&2
  exit 1
fi

if [[ -z "$yaml_instructions" ]]; then
  echo "Missing definition.instructions block in $AGENT_YAML_PATH" >&2
  exit 1
fi

env_existing_agent_id="$(azd_env_get AZURE_EXISTING_AGENT_ID)"
env_existing_agent_id="$(strip_wrapping_quotes "$env_existing_agent_id")"

env_agent_name=""
env_agent_version=""
if [[ -n "$env_existing_agent_id" ]]; then
  if mapfile -t parsed < <(parse_agent_id "$env_existing_agent_id"); then
    env_agent_name="${parsed[0]}"
    env_agent_version="${parsed[1]}"
  else
    echo "AZURE_EXISTING_AGENT_ID is not in name:version format: $env_existing_agent_id" >&2
    exit 1
  fi
fi

selected_agent_name="$yaml_agent_name"
selected_agent_version="$yaml_agent_version"
selected_agent_id="$yaml_agent_id"
prefer_env_agent_id=false

if [[ -n "$env_existing_agent_id" ]]; then
  if [[ -n "$yaml_agent_id" && "$yaml_agent_id" != "$env_existing_agent_id" ]]; then
    echo "YAML agent id differs from azd env AZURE_EXISTING_AGENT_ID. Using azd env value as requested."
    prefer_env_agent_id=true
  fi

  if [[ "$prefer_env_agent_id" == true || -z "$selected_agent_name" ]]; then
    selected_agent_name="$env_agent_name"
    selected_agent_version="$env_agent_version"
    selected_agent_id="$env_existing_agent_id"
  fi
fi

selected_agent_name="$(prompt_if_empty "selected_agent_name" "Foundry agent name: " "$selected_agent_name")"

# If tools is not inline JSON, default to empty array.
tools_json="[]"
if [[ -n "$yaml_tools_inline" ]]; then
  yaml_tools_inline="$(strip_wrapping_quotes "$yaml_tools_inline")"
  if [[ "$yaml_tools_inline" == "[]" ]]; then
    tools_json='[]'
  elif echo "$yaml_tools_inline" | jq -e . >/dev/null 2>&1; then
    tools_json="$yaml_tools_inline"
  fi
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

create_body_file="$tmp_dir/create-agent.json"
update_body_file="$tmp_dir/update-agent.json"
response_file="$tmp_dir/response.json"
versions_file="$tmp_dir/versions.json"

jq -n \
  --arg name "$selected_agent_name" \
  --arg description "$yaml_description" \
  --arg kind "$yaml_kind" \
  --arg model "$yaml_model" \
  --arg instructions "$yaml_instructions" \
  --argjson tools "$tools_json" \
  '{
    name: $name,
    description: $description,
    definition: {
      kind: $kind,
      model: $model,
      instructions: $instructions,
      tools: $tools
    }
  }' >"$create_body_file"

jq -n \
  --arg description "$yaml_description" \
  --arg kind "$yaml_kind" \
  --arg model "$yaml_model" \
  --arg instructions "$yaml_instructions" \
  --argjson tools "$tools_json" \
  '{
    description: $description,
    definition: {
      kind: $kind,
      model: $model,
      instructions: $instructions,
      tools: $tools
    }
  }' >"$update_body_file"

echo "Acquiring Foundry token via Azure CLI..."
access_token="$(az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv 2>/dev/null || true)"
if [[ -z "$access_token" ]]; then
  access_token="$(az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv)"
fi

encoded_agent_name="$(jq -rn --arg v "$selected_agent_name" '$v|@uri')"

update_url="$PROJECT_ENDPOINT/agents/$encoded_agent_name?api-version=v1"
create_url="$PROJECT_ENDPOINT/agents?api-version=v1"

# Attempt update first; if the agent does not exist, create it.
echo "Creating/updating Foundry agent '$selected_agent_name' from $AGENT_YAML_PATH ..."
http_code="$(curl_json "POST" "$update_url" "$access_token" "$update_body_file" "$response_file")"
if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
  echo "Agent updated successfully."
else
  if [[ "$http_code" == "404" ]]; then
    echo "Agent not found; creating a new agent."
    http_code="$(curl_json "POST" "$create_url" "$access_token" "$create_body_file" "$response_file")"
    if [[ ! ( "$http_code" -ge 200 && "$http_code" -lt 300 ) ]]; then
      echo "Agent create failed (HTTP $http_code). Response:" >&2
      cat "$response_file" >&2
      exit 1
    fi
    echo "Agent created successfully."
  else
    echo "Agent update failed (HTTP $http_code). Response:" >&2
    cat "$response_file" >&2
    exit 1
  fi
fi

# Determine the latest agent version.
list_versions_url="$PROJECT_ENDPOINT/agents/$encoded_agent_name/versions?limit=1&order=desc&api-version=v1"
http_code="$(curl_json "GET" "$list_versions_url" "$access_token" "" "$versions_file")"
latest_version=""
if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
  latest_version="$(jq -r '.data[0].version // empty' "$versions_file")"
fi

response_name="$(jq -r '.name // empty' "$response_file")"
if [[ -z "$response_name" ]]; then
  response_name="$selected_agent_name"
fi

response_version="$(jq -r '.version // .current_version // .latest_version.version // .latest_version // empty' "$response_file")"
if [[ -z "$response_version" ]]; then
  response_version="$latest_version"
fi

final_agent_name="$response_name"
final_agent_version="$response_version"
final_agent_id=""

# Requirement: if YAML id differs from azd .env id, use azd env value.
if [[ "$prefer_env_agent_id" == true && -n "$env_existing_agent_id" ]]; then
  final_agent_id="$env_existing_agent_id"
  final_agent_name="$env_agent_name"
  final_agent_version="$env_agent_version"
else
  if [[ -z "$final_agent_name" ]]; then
    final_agent_name="$selected_agent_name"
  fi
  if [[ -z "$final_agent_version" ]]; then
    final_agent_version="$selected_agent_version"
  fi

  if [[ -n "$final_agent_name" && -n "$final_agent_version" ]]; then
    final_agent_id="$final_agent_name:$final_agent_version"
  elif [[ -n "$selected_agent_id" ]]; then
    final_agent_id="$selected_agent_id"
  fi
fi

if [[ -z "$final_agent_id" ]]; then
  echo "Could not determine final agent id. Set AZURE_EXISTING_AGENT_ID manually." >&2
  exit 1
fi

if [[ -z "$final_agent_name" || -z "$final_agent_version" ]]; then
  if mapfile -t parsed < <(parse_agent_id "$final_agent_id"); then
    final_agent_name="${parsed[0]}"
    final_agent_version="${parsed[1]}"
  fi
fi

if [[ -z "$final_agent_name" || -z "$final_agent_version" ]]; then
  echo "Could not determine final agent name/version from final agent id: $final_agent_id" >&2
  exit 1
fi

# Keep azd env aligned for future script runs.
if command -v azd >/dev/null 2>&1; then
  azd env set AZURE_EXISTING_AIPROJECT_ENDPOINT "$PROJECT_ENDPOINT" >/dev/null
  azd env set AZURE_EXISTING_AGENT_ID "$final_agent_id" >/dev/null
  azd env set AZURE_FOUNDRY_AGENT_NAME "$final_agent_name" >/dev/null
  azd env set AZURE_FOUNDRY_AGENT_VERSION "$final_agent_version" >/dev/null
fi

# Update local Function settings file.
local_settings_path="function/local.settings.json"
local_settings_example="function/local.settings.json.example"
if [[ ! -f "$local_settings_path" ]]; then
  if [[ -f "$local_settings_example" ]]; then
    cp "$local_settings_example" "$local_settings_path"
    echo "Created $local_settings_path from example."
  else
    cat >"$local_settings_path" <<'JSON'
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "node"
  }
}
JSON
    echo "Created new $local_settings_path."
  fi
fi

tmp_local="$tmp_dir/local.settings.json"
jq \
  --arg endpoint "$PROJECT_ENDPOINT" \
  --arg agentId "$final_agent_id" \
  --arg agentName "$final_agent_name" \
  --arg agentVersion "$final_agent_version" \
  '.Values = (.Values // {})
   | .Values.AZURE_EXISTING_AIPROJECT_ENDPOINT = $endpoint
   | .Values.AZURE_EXISTING_AGENT_ID = $agentId
   | .Values.AZURE_FOUNDRY_AGENT_NAME = $agentName
   | .Values.AZURE_FOUNDRY_AGENT_VERSION = $agentVersion' \
  "$local_settings_path" >"$tmp_local"
mv "$tmp_local" "$local_settings_path"

# Update Azure Function App settings.
echo "Updating Azure Function App app settings..."
az functionapp config appsettings set \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --settings \
    AZURE_EXISTING_AIPROJECT_ENDPOINT="$PROJECT_ENDPOINT" \
    AZURE_EXISTING_AGENT_ID="$final_agent_id" \
    AZURE_FOUNDRY_AGENT_NAME="$final_agent_name" \
    AZURE_FOUNDRY_AGENT_VERSION="$final_agent_version" >/dev/null

echo "Done."
echo "Project endpoint: $PROJECT_ENDPOINT"
echo "Agent id:        $final_agent_id"
echo "Agent name:      $final_agent_name"
echo "Agent version:   $final_agent_version"
echo "Resource group:  $RESOURCE_GROUP"
echo "Function app:    $FUNCTION_APP_NAME"
