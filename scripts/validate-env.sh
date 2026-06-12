#!/usr/bin/env bash
set -euo pipefail

if ! command -v azd >/dev/null 2>&1; then
  echo "azd is required but not installed." >&2
  exit 1
fi

required_vars=(AZURE_LOCATION PREFIX VNET_RESOURCE_ID)
missing=()

for var_name in "${required_vars[@]}"; do
  value="$(azd env get-value "$var_name" 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    missing+=("$var_name")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing required azd environment variables:" >&2
  for name in "${missing[@]}"; do
    echo "  - $name" >&2
  done
  echo "Set them with: azd env set <NAME> <VALUE>" >&2
  exit 1
fi

echo "All required azd variables are present."
for var_name in "${required_vars[@]}"; do
  echo "- $var_name=$(azd env get-value "$var_name")"
done
