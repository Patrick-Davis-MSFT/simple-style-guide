#!/usr/bin/env bash
set -euo pipefail

if ! command -v azd >/dev/null 2>&1; then
  echo "azd is required." >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required." >&2
  exit 1
fi

storage_account_name="$(azd env get-value AZURE_STORAGE_ACCOUNT_NAME 2>/dev/null || true)"
if [[ -z "$storage_account_name" ]]; then
  echo "Could not resolve AZURE_STORAGE_ACCOUNT_NAME from azd environment." >&2
  exit 1
fi

assets_dir="app-ui/public/assets"
if [[ ! -d "$assets_dir" ]]; then
  echo "Assets directory not found: $assets_dir" >&2
  exit 1
fi

shopt -s nullglob
icon_files=("$assets_dir"/icon-*.png)
shopt -u nullglob

if [[ ${#icon_files[@]} -eq 0 ]]; then
  echo "No icon files found in $assets_dir (expected icon-*.png)."
  exit 0
fi

# Ensure the destination container exists and is anonymously readable at blob level.
container_exists="$(az storage container exists \
  --auth-mode login \
  --account-name "$storage_account_name" \
  --name '$web' \
  --query exists -o tsv)"

if [[ "$container_exists" != "true" ]]; then
  az storage container create \
    --auth-mode login \
    --account-name "$storage_account_name" \
    --name '$web' \
    --public-access blob \
    >/dev/null
fi

for icon_file in "${icon_files[@]}"; do
  icon_name="$(basename "$icon_file")"

  az storage blob upload \
    --auth-mode login \
    --account-name "$storage_account_name" \
    --container-name '$web' \
    --name "assets/$icon_name" \
    --file "$icon_file" \
    --overwrite true \
    >/dev/null

  echo "Uploaded assets/$icon_name"
done

echo "Icon upload complete for storage account: $storage_account_name"
