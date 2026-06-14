#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd -- "$script_dir/.." && pwd)"
cd "$workspace_root"

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

az storage blob service-properties update \
  --auth-mode login \
  --account-name "$storage_account_name" \
  --static-website true \
  --index-document index.html \
  --404-document 404.html \
  >/dev/null

echo "Enabled static website settings on storage account: $storage_account_name"
