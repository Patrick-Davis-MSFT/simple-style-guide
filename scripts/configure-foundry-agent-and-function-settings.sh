#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/configure-foundry-agent-and-function-settings.sh [options]

Options:
  --project-endpoint <url>  Foundry project endpoint (for example: https://<account>.services.ai.azure.com/api/projects/<project>)
  --agent-yaml <path>       Agent YAML path (default: agents/styleGuide.yaml)
  --env-name <name>         azd environment name (default: current/default env)
  --function-app <name>     Azure Function App name (fallback: AZURE_FUNCTION_APP_NAME or FUNCTION_APP_NAME from azd env)
  --resource-group <name>   Azure Resource Group (fallback: AZURE_RESOURCE_GROUP from azd env)
  --subscription-id <id>    Azure subscription (fallback: AZURE_SUBSCRIPTION_ID from azd env)
  -h, --help                Show this help

Behavior:
  1. Creates/updates a Foundry agent from YAML definition using az login auth.
  2. Updates local Function settings in function/local.settings.json (creates from example if needed).
  3. Updates Azure Function App settings in the deployed service.

Priority rule:
  If AZURE_EXISTING_AGENT_ID exists in azd .env and differs from YAML id, azd .env value is used for function settings.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
}

prompt_if_empty() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="${3-}"
  local current_value="${!var_name-}"

  if [[ -n "$current_value" ]]; then
    return 0
  fi

  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt_text [$default_value]: " input
    if [[ -z "$input" ]]; then
      input="$default_value"
    fi
  else
    read -r -p "$prompt_text: " input
  fi

  printf -v "$var_name" '%s' "$input"
}

strip_quotes() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  printf '%s' "$value"
}

get_azd_value() {
  local key="$1"
  local env_name="${2-}"
  local value

  if [[ -n "$env_name" ]]; then
    value="$(azd env get-value "$key" -e "$env_name" 2>/dev/null || true)"
  else
    value="$(azd env get-value "$key" 2>/dev/null || true)"
  fi

  value="$(strip_quotes "$value")"
  printf '%s' "$value"
}

ensure_az_login() {
  if ! az account show >/dev/null 2>&1; then
    echo "No active Azure login found. Starting 'az login'..."
    az login >/dev/null
  fi
}

parse_yaml_scalar() {
  local yaml_file="$1"
  local key_pattern="$2"
  local value

  value="$(awk -v pat="$key_pattern" '
    $0 ~ pat {
      sub(/^[^:]+:[[:space:]]*/, "", $0)
      gsub(/^"|"$/, "", $0)
      print
      exit
    }
  ' "$yaml_file")"

  printf '%s' "$value"
}

extract_yaml_instructions() {
  local yaml_file="$1"

  awk '
    BEGIN { in_block = 0 }
    /^  instructions:[[:space:]]*\|-/ { in_block = 1; next }
    in_block == 1 {
      if ($0 ~ /^  [^[:space:]][^:]*:/) {
        in_block = 0
        exit
      }
      line = $0
      sub(/^    /, "", line)
      print line
    }
  ' "$yaml_file"
}

build_definition_json() {
  local yaml_file="$1"
  local kind
  local model
  local instructions
  local tools_raw

  kind="$(parse_yaml_scalar "$yaml_file" "^  kind:[[:space:]]")"
  model="$(parse_yaml_scalar "$yaml_file" "^  model:[[:space:]]")"
  instructions="$(extract_yaml_instructions "$yaml_file")"
  tools_raw="$(parse_yaml_scalar "$yaml_file" "^  tools:[[:space:]]")"

  if [[ -z "$kind" || -z "$model" || -z "$instructions" ]]; then
    echo "Agent YAML is missing required fields under definition (kind/model/instructions)." >&2
    exit 1
  fi

  if [[ "$tools_raw" == "[]" ]]; then
    jq -n \
      --arg kind "$kind" \
      --arg model "$model" \
      --arg instructions "$instructions" \
      '{kind:$kind, model:$model, instructions:$instructions, tools: []}'
  else
    jq -n \
      --arg kind "$kind" \
      --arg model "$model" \
      --arg instructions "$instructions" \
      '{kind:$kind, model:$model, instructions:$instructions}'
  fi
}

parse_agent_id() {
  local agent_id="$1"
  local name=""
  local version=""

  if [[ "$agent_id" == *:* ]]; then
    name="${agent_id%:*}"
    version="${agent_id##*:}"
  fi

  printf '%s\n%s\n' "$name" "$version"
}

project_endpoint=""
agent_yaml="agents/styleGuide.yaml"
env_name=""
function_app_name=""
resource_group=""
subscription_id=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-endpoint)
      project_endpoint="${2-}"
      shift 2
      ;;
    --agent-yaml)
      agent_yaml="${2-}"
      shift 2
      ;;
    --env-name)
      env_name="${2-}"
      shift 2
      ;;
    --function-app)
      function_app_name="${2-}"
      shift 2
      ;;
    --resource-group)
      resource_group="${2-}"
      shift 2
      ;;
    --subscription-id)
      subscription_id="${2-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd az
require_cmd jq
require_cmd awk
require_cmd sed

if ! command -v azd >/dev/null 2>&1; then
  echo "Warning: azd not found. .env-derived defaults will be limited."
fi

if [[ ! -f "$agent_yaml" ]]; then
  echo "Agent YAML not found: $agent_yaml" >&2
  exit 1
fi

if command -v azd >/dev/null 2>&1; then
  azd_project_endpoint="$(get_azd_value "AZURE_EXISTING_AIPROJECT_ENDPOINT" "$env_name")"
  azd_existing_agent_id="$(get_azd_value "AZURE_EXISTING_AGENT_ID" "$env_name")"
  azd_function_app_name="$(get_azd_value "AZURE_FUNCTION_APP_NAME" "$env_name")"
  if [[ -z "$azd_function_app_name" ]]; then
    azd_function_app_name="$(get_azd_value "FUNCTION_APP_NAME" "$env_name")"
  fi
  azd_resource_group="$(get_azd_value "AZURE_RESOURCE_GROUP" "$env_name")"
  azd_subscription_id="$(get_azd_value "AZURE_SUBSCRIPTION_ID" "$env_name")"
else
  azd_project_endpoint=""
  azd_existing_agent_id=""
  azd_function_app_name=""
  azd_resource_group=""
  azd_subscription_id=""
fi

if [[ -z "$project_endpoint" ]]; then
  project_endpoint="$azd_project_endpoint"
fi
if [[ -z "$function_app_name" ]]; then
  function_app_name="$azd_function_app_name"
fi
if [[ -z "$resource_group" ]]; then
  resource_group="$azd_resource_group"
fi
if [[ -z "$subscription_id" ]]; then
  subscription_id="$azd_subscription_id"
fi

prompt_if_empty project_endpoint "Enter Foundry project endpoint" "$azd_project_endpoint"
prompt_if_empty function_app_name "Enter Azure Function App name" "$azd_function_app_name"
prompt_if_empty resource_group "Enter Azure Resource Group" "$azd_resource_group"

if [[ -z "$project_endpoint" || -z "$function_app_name" || -z "$resource_group" ]]; then
  echo "Missing required inputs. Project endpoint, Function App name, and Resource Group are required." >&2
  exit 1
fi

yaml_agent_id="$(parse_yaml_scalar "$agent_yaml" "^id:[[:space:]]")"
yaml_agent_name="$(parse_yaml_scalar "$agent_yaml" "^name:[[:space:]]")"

if [[ -z "$yaml_agent_name" ]]; then
  echo "Missing top-level 'name' in $agent_yaml" >&2
  exit 1
fi

if [[ -n "$subscription_id" ]]; then
  echo "Setting Azure subscription: $subscription_id"
  az account set --subscription "$subscription_id"
fi

ensure_az_login

definition_json="$(build_definition_json "$agent_yaml")"

if [[ -n "$azd_existing_agent_id" ]]; then
  readarray -t parsed_env_agent < <(parse_agent_id "$azd_existing_agent_id")
  env_agent_name="${parsed_env_agent[0]}"
  env_agent_version="${parsed_env_agent[1]}"
else
  env_agent_name=""
  env_agent_version=""
fi

if [[ -n "$env_agent_name" && "$env_agent_name" != "$yaml_agent_name" ]]; then
  echo "YAML agent name '$yaml_agent_name' differs from azd .env agent '$env_agent_name'."
  echo "Using azd .env agent name per precedence rule."
fi

target_agent_name="$yaml_agent_name"
if [[ -n "$env_agent_name" ]]; then
  target_agent_name="$env_agent_name"
fi

token="$(az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv)"

create_payload="$(jq -n \
  --arg name "$target_agent_name" \
  --argjson definition "$definition_json" \
  '{name:$name, definition:$definition}')"

update_payload="$(jq -n \
  --argjson definition "$definition_json" \
  '{definition:$definition}')"

echo "Creating or updating Foundry agent '$target_agent_name'..."

http_status="$(
  curl -sS -o /tmp/foundry_agent_get.json -w '%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    "$project_endpoint/agents/$target_agent_name?api-version=v1"
)"

if [[ "$http_status" == "200" ]]; then
  response_json="$(
    curl -sS \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -X POST \
      "$project_endpoint/agents/$target_agent_name?api-version=v1" \
      -d "$update_payload"
  )"
elif [[ "$http_status" == "404" ]]; then
  response_json="$(
    curl -sS \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -X POST \
      "$project_endpoint/agents?api-version=v1" \
      -d "$create_payload"
  )"
else
  echo "Unexpected response while checking existing agent: HTTP $http_status" >&2
  if [[ -f /tmp/foundry_agent_get.json ]]; then
    cat /tmp/foundry_agent_get.json >&2
  fi
  exit 1
fi

if ! echo "$response_json" | jq . >/dev/null 2>&1; then
  echo "Foundry API returned a non-JSON response:" >&2
  echo "$response_json" >&2
  exit 1
fi

created_agent_name="$(echo "$response_json" | jq -r '.name // empty')"
created_agent_version="$(echo "$response_json" | jq -r '.version // empty')"

if [[ -z "$created_agent_name" ]]; then
  created_agent_name="$target_agent_name"
fi

if [[ -z "$created_agent_version" || "$created_agent_version" == "null" ]]; then
  if [[ -n "$env_agent_version" ]]; then
    created_agent_version="$env_agent_version"
  else
    created_agent_version="1"
  fi
fi

resolved_agent_id="$created_agent_name:$created_agent_version"
if [[ -n "$azd_existing_agent_id" ]]; then
  if [[ -n "$yaml_agent_id" && "$yaml_agent_id" != "$azd_existing_agent_id" ]]; then
    echo "YAML id '$yaml_agent_id' differs from azd .env id '$azd_existing_agent_id'."
    echo "Using azd .env id per precedence rule."
  fi
  resolved_agent_id="$azd_existing_agent_id"

  readarray -t parsed_resolved < <(parse_agent_id "$resolved_agent_id")
  if [[ -n "${parsed_resolved[0]}" ]]; then
    created_agent_name="${parsed_resolved[0]}"
  fi
  if [[ -n "${parsed_resolved[1]}" ]]; then
    created_agent_version="${parsed_resolved[1]}"
  fi
fi

local_settings_path="function/local.settings.json"
local_settings_example="function/local.settings.json.example"

if [[ ! -f "$local_settings_path" ]]; then
  if [[ -f "$local_settings_example" ]]; then
    cp "$local_settings_example" "$local_settings_path"
    echo "Created $local_settings_path from example."
  else
    cat > "$local_settings_path" <<'EOF'
{
  "IsEncrypted": false,
  "Values": {}
}
EOF
    echo "Created $local_settings_path with minimal template."
  fi
fi

tmp_local_settings="$(mktemp)"
jq \
  --arg endpoint "$project_endpoint" \
  --arg agentId "$resolved_agent_id" \
  --arg agentName "$created_agent_name" \
  --arg agentVersion "$created_agent_version" \
  '
  .Values = (.Values // {})
  | .Values.AZURE_EXISTING_AIPROJECT_ENDPOINT = $endpoint
  | .Values.AZURE_EXISTING_AGENT_ID = $agentId
  | .Values.AZURE_FOUNDRY_AGENT_NAME = $agentName
  | .Values.AZURE_FOUNDRY_AGENT_VERSION = $agentVersion
  ' "$local_settings_path" > "$tmp_local_settings"
mv "$tmp_local_settings" "$local_settings_path"

echo "Updated $local_settings_path"

echo "Updating Azure Function App settings on '$function_app_name'..."
az functionapp config appsettings set \
  --name "$function_app_name" \
  --resource-group "$resource_group" \
  --settings \
    "AZURE_EXISTING_AIPROJECT_ENDPOINT=$project_endpoint" \
    "AZURE_EXISTING_AGENT_ID=$resolved_agent_id" \
    "AZURE_FOUNDRY_AGENT_NAME=$created_agent_name" \
    "AZURE_FOUNDRY_AGENT_VERSION=$created_agent_version" \
  --only-show-errors >/dev/null

echo
echo "Done."
echo "Foundry project endpoint: $project_endpoint"
echo "Agent reference: $resolved_agent_id"
echo "Function App: $function_app_name"
echo "Resource Group: $resource_group"
