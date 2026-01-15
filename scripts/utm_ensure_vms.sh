#!/usr/bin/env bash
set -euo pipefail

# data.external passes inputs via STDIN JSON; fall back to env/defaults if missing.
if [[ -z "${TEMPLATE_NAME:-}" || -z "${APP_NAME:-}" || -z "${DB_NAME:-}" ]]; then
  if [[ ! -t 0 ]]; then
    assignments="$(
      /usr/bin/python3 - <<'PY'
import json, sys
raw = sys.stdin.read()
data = json.loads(raw) if raw.strip() else {}

def pick(*keys):
    for key in keys:
        value = data.get(key, "")
        if value:
            return value
    return ""

mapping = {
    "TEMPLATE_NAME": ("TEMPLATE_NAME", "template_name"),
    "APP_NAME": ("APP_NAME", "app_name"),
    "DB_NAME": ("DB_NAME", "db_name"),
}

for env_key, keys in mapping.items():
    value = pick(*keys)
    if value:
        print(f"{env_key}={value}")
PY
    )"
    if [[ -n "$assignments" ]]; then
      eval "$assignments"
    fi
  fi
fi

TEMPLATE_NAME="${TEMPLATE_NAME:-tmpl-ubuntu}"
APP_NAME="${APP_NAME:-app-vm}"
DB_NAME="${DB_NAME:-db-vm}"
export TEMPLATE_NAME APP_NAME DB_NAME

if [[ -z "${TEMPLATE_NAME}" || -z "${APP_NAME}" || -z "${DB_NAME}" ]]; then
  echo "utm_ensure_vms: missing names TEMPLATE_NAME='${TEMPLATE_NAME}' APP_NAME='${APP_NAME}' DB_NAME='${DB_NAME}'" >&2
  exit 1
fi

utmctl_bin="/Applications/UTM.app/Contents/MacOS/utmctl"

ensure_vm() {
  local vm_name="$1"
  local template_name="$2"
  local ip=""
  local status=""
  local ip_raw=""

  if ! "$utmctl_bin" list | tail -n +2 | sed -E 's/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+//' | grep -Fxq "$vm_name"; then
    "$utmctl_bin" clone "$template_name" --name "$vm_name" --hide >/dev/null
  fi

  "$utmctl_bin" start "$vm_name" >/dev/null 2>&1 || true

  for _ in {1..120}; do
    status="$("$utmctl_bin" status "$vm_name" 2>/dev/null || true)"
    if [[ "$status" == "started" ]]; then
      break
    fi
    sleep 1
  done

  for _ in {1..60}; do
    ip_raw="$("$utmctl_bin" ip-address "$vm_name" 2>/dev/null || true)"
    if grep -qiE 'error from event|guest agent' <<<"$ip_raw"; then
      ip_raw=""
    fi
    ip="$(printf '%s\n' "$ip_raw" | grep -m1 -E '^[0-9]+\\.' || true)"
    if [[ -z "$ip" ]]; then
      ip="$(printf '%s\n' "$ip_raw" | head -n1 | tr -d '\r')"
    fi
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
    sleep 2
  done

  echo "no IP from guest agent for ${vm_name}" >&2
  return 1
}

app_ip="$(ensure_vm "$APP_NAME" "$TEMPLATE_NAME")"
db_ip="$(ensure_vm "$DB_NAME" "$TEMPLATE_NAME")"

printf '{"app_ip":"%s","db_ip":"%s"}\n' "$app_ip" "$db_ip"
