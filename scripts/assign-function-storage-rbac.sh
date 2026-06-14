#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd -- "$script_dir/.." && pwd)"
cd "$workspace_root"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required." >&2
  exit 1
fi

if ! command -v azd >/dev/null 2>&1; then
  echo "Azure Developer CLI (azd) is required." >&2
  exit 1
fi

function_app_name="$(azd env get-value AZURE_FUNCTION_APP_NAME 2>/dev/null || true)"
storage_account_name="$(azd env get-value AZURE_STORAGE_ACCOUNT_NAME 2>/dev/null || true)"
subscription_id="$(azd env get-value AZURE_SUBSCRIPTION_ID 2>/dev/null || true)"

if [[ -z "$function_app_name" || -z "$storage_account_name" ]]; then
  echo "Missing AZURE_FUNCTION_APP_NAME or AZURE_STORAGE_ACCOUNT_NAME in azd environment." >&2
  exit 1
fi

if [[ -n "$subscription_id" ]]; then
  az account set --subscription "$subscription_id"
fi

principal_id="$(az functionapp identity show --name "$function_app_name" --query principalId -o tsv)"
storage_id="$(az storage account show --name "$storage_account_name" --query id -o tsv)"

roles=(
  "Storage Blob Data Contributor"
  "Storage Queue Data Contributor"
  "Storage Table Data Contributor"
)

for role in "${roles[@]}"; do
  az role assignment create \
    --assignee-object-id "$principal_id" \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope "$storage_id" \
    --only-show-errors >/dev/null || true
  echo "Ensured role '$role' on $storage_account_name"
done

echo "RBAC assignment script completed."
