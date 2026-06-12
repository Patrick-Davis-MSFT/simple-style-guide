#!/usr/bin/env bash
set -euo pipefail

heartbeat_url="${1:-${HEARTBEAT_URL:-http://localhost:7071/api/heartbeat}}"
function_key="${2:-${FUNCTION_KEY:-}}"

resolve_from_azd="${RESOLVE_FROM_AZD:-false}"

if [[ -z "$function_key" && "$resolve_from_azd" == "true" ]]; then
  if ! command -v azd >/dev/null 2>&1 || ! command -v az >/dev/null 2>&1; then
    echo "azd and az are required when RESOLVE_FROM_AZD=true." >&2
    exit 1
  fi

  resource_group="$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null || true)"
  function_app_name="$(azd env get-value AZURE_FUNCTION_APP_NAME 2>/dev/null || true)"

  if [[ -z "$function_app_name" ]]; then
    function_app_name="$(azd env get-value FUNCTION_APP_NAME 2>/dev/null || true)"
  fi

  if [[ -z "$resource_group" || -z "$function_app_name" ]]; then
    echo "Unable to resolve Function App details from azd environment." >&2
    echo "Set AZURE_RESOURCE_GROUP and AZURE_FUNCTION_APP_NAME outputs or pass URL/key explicitly." >&2
    exit 1
  fi

  if [[ "${1:-}" == "" && "${HEARTBEAT_URL:-}" == "" ]]; then
    heartbeat_url="https://${function_app_name}.azurewebsites.net/api/heartbeat"
  fi

  function_key="$(az functionapp keys list \
    --resource-group "$resource_group" \
    --name "$function_app_name" \
    --query "functionKeys.default" \
    -o tsv)"
fi

if [[ -z "$function_key" ]]; then
  echo "Function key is required." >&2
  echo "Usage: bash scripts/ping-heartbeat.sh [heartbeat_url] [function_key]" >&2
  echo "Or set FUNCTION_KEY and optionally HEARTBEAT_URL environment variables." >&2
  echo "For deployed apps, you can set RESOLVE_FROM_AZD=true to auto-resolve URL/key." >&2
  exit 1
fi

tmp_response_file="$(mktemp)"
http_status="$(curl -sS -o "$tmp_response_file" -w "%{http_code}" -H "x-functions-key: ${function_key}" "$heartbeat_url")"

echo "Heartbeat URL: $heartbeat_url"
echo "HTTP status: $http_status"
cat "$tmp_response_file"
echo

rm -f "$tmp_response_file"
