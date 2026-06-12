#!/usr/bin/env bash
set -euo pipefail

if ! command -v azd >/dev/null 2>&1; then
  echo "azd is required." >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: bash scripts/sync-manifest-from-azd.sh [--localhost] [--host <url>]

Options:
  --localhost   Set manifest URLs to https://localhost:3000
  --host <url>  Override manifest URLs to a specific host (for example https://myapp.example.com)
  -h, --help    Show this help message
EOF
}

mode="azure"
host_override=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --localhost)
      mode="localhost"
      shift
      ;;
    --host)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --host" >&2
        usage
        exit 1
      fi
      host_override="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [[ "$mode" == "localhost" && -n "$host_override" ]]; then
  echo "Cannot use --localhost and --host together." >&2
  exit 1
fi

manifest_path="app-ui/manifest.xml"
if [[ ! -f "$manifest_path" ]]; then
  echo "Manifest not found at $manifest_path" >&2
  exit 1
fi

if [[ -n "$host_override" ]]; then
  if [[ "$host_override" =~ ^https?://[^/]+$ ]]; then
    host="$host_override"
  else
    echo "--host must be a host URL without a path (for example https://myapp.example.com)." >&2
    exit 1
  fi
elif [[ "$mode" == "localhost" ]]; then
  host="https://localhost:3000"
else
  taskpane_url="$(azd env get-value OFFICE_ADDIN_TASKPANE_URL 2>/dev/null || true)"
  static_web_app_url="$(azd env get-value STATIC_WEB_APP_URL 2>/dev/null || true)"
  azure_static_web_app_url="$(azd env get-value AZURE_STATIC_WEB_APP_URL 2>/dev/null || true)"

  host=""
  for candidate in "$taskpane_url" "$static_web_app_url" "$azure_static_web_app_url"; do
    if [[ -n "$candidate" ]]; then
      if [[ "$candidate" =~ ^https?://[^/]+ ]]; then
        host="${BASH_REMATCH[0]}"
        break
      fi
    fi
  done

  if [[ -z "$host" ]]; then
    swa_name="$(azd env get-value AZURE_STATIC_WEB_APP_NAME 2>/dev/null || true)"
    if [[ -z "$swa_name" ]]; then
      swa_name="$(azd env get-value STATIC_WEB_APP_NAME 2>/dev/null || true)"
    fi

    if [[ -z "$swa_name" ]]; then
      echo "Could not resolve Static Web App URL from azd outputs." >&2
      echo "Expected one of: OFFICE_ADDIN_TASKPANE_URL, STATIC_WEB_APP_URL, AZURE_STATIC_WEB_APP_URL, AZURE_STATIC_WEB_APP_NAME." >&2
      exit 1
    fi

    host="https://${swa_name}.azurestaticapps.net"
  fi
fi

escaped_host="$(printf '%s' "$host" | sed 's/[&#/]/\\&/g')"

sed -E -i \
  "s#https?://(localhost:3000|[[:alnum:]-]+(\.[[:alnum:]-]+)?\.azurestaticapps\.net)#$escaped_host#g" \
  "$manifest_path"

echo "Updated manifest URLs to ${host}"
