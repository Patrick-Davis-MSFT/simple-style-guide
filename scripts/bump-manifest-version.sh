#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd -- "$script_dir/.." && pwd)"
cd "$workspace_root"
manifest_path="$workspace_root/app-ui/manifest.xml"
manifest_source_path="$workspace_root/app-ui/manifest.source.xml"

if ! command -v azd >/dev/null 2>&1; then
  echo "azd is required." >&2
  exit 1
fi

if [[ ! -f "$manifest_source_path" ]]; then
  echo "Manifest source not found at $manifest_source_path" >&2
  exit 1
fi

# Rebuild the working manifest from source before applying environment-specific values.
cp "$manifest_source_path" "$manifest_path"

if [[ ! -f "$manifest_path" ]]; then
  echo "Manifest not found at $manifest_path" >&2
  exit 1
fi

azure_client_id="$(azd env get-value AZURE_CLIENT_ID 2>/dev/null || true)"
azure_client_app_id_uri="$(azd env get-value AZURE_CLIENT_APP_ID_URI 2>/dev/null || true)"

if [[ -z "$azure_client_id" ]]; then
  echo "Could not resolve AZURE_CLIENT_ID from azd environment." >&2
  exit 1
fi

if [[ -z "$azure_client_app_id_uri" ]]; then
  echo "Could not resolve AZURE_CLIENT_APP_ID_URI from azd environment." >&2
  exit 1
fi

escaped_client_id="$(printf '%s' "$azure_client_id" | sed 's/[\/&]/\\&/g')"
escaped_client_app_id_uri="$(printf '%s' "$azure_client_app_id_uri" | sed 's/[\/&]/\\&/g')"

# Update the Office SSO section with values from azd environment outputs.
sed -E -i \
  "/<WebApplicationInfo>/,/<\\/WebApplicationInfo>/ s#<Id>[^<]+</Id>#<Id>${escaped_client_id}</Id>#" \
  "$manifest_path"

sed -E -i \
  "/<WebApplicationInfo>/,/<\\/WebApplicationInfo>/ s#<Resource>[^<]+</Resource>#<Resource>${escaped_client_app_id_uri}</Resource>#" \
  "$manifest_path"

current_version="$(sed -n 's#.*<Version>\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)</Version>.*#\1#p' "$manifest_path" | head -n1)"

if [[ -z "$current_version" ]]; then
  echo "Could not parse <Version> from $manifest_path" >&2
  exit 1
fi

IFS='.' read -r major minor build revision <<< "$current_version"
next_revision=$((revision + 1))
next_version="${major}.${minor}.${build}.${next_revision}"

sed -E -i "s#(<Version>)${major}\\.${minor}\\.${build}\\.${revision}(</Version>)#\\1${next_version}\\2#" "$manifest_path"

echo "Bumped manifest version: ${current_version} -> ${next_version}"
