#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd -- "$script_dir/.." && pwd)"
cd "$workspace_root"
manifest_source="$workspace_root/app-ui/manifest.xml"
assets_source_dir="$workspace_root/app-ui/public/assets"
output_zip="$workspace_root/office365-upload.zip"
staging_dir="$workspace_root/.tmp-office365-upload"

required_files=(
  "$manifest_source"
  "$assets_source_dir/icon-16.png"
  "$assets_source_dir/icon-32.png"
  "$assets_source_dir/icon-80.png"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Required file missing: $file" >&2
    exit 1
  fi
done

rm -rf "$staging_dir"
mkdir -p "$staging_dir/assets"
cp "$manifest_source" "$staging_dir/manifest.xml"
cp "$assets_source_dir/icon-16.png" "$staging_dir/assets/icon-16.png"
cp "$assets_source_dir/icon-32.png" "$staging_dir/assets/icon-32.png"
cp "$assets_source_dir/icon-80.png" "$staging_dir/assets/icon-80.png"

(
  cd "$staging_dir"
  zip -rq "$output_zip" manifest.xml assets
)

rm -rf "$staging_dir"
echo "Created $output_zip"
