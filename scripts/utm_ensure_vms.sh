#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_NAME="${TEMPLATE_NAME:-tmpl-ubuntu}"
APP_NAME="${APP_NAME:-app-vm}"
DB_NAME="${DB_NAME:-db-vm}"

json=$(/usr/bin/osascript <<'APPLESCRIPT'
on ensure_vm(vmName, templateName)
  tell application "UTM"
    try
      set vm to virtual machine named vmName
    on error
      set tmpl to virtual machine named templateName
      set vm to duplicate tmpl with properties {configuration:{name:vmName}}
    end try

    -- start if not started
    if status of vm is not "started" then
      start vm
    end if

    -- wait until started
    repeat
      if status of vm is "started" then exit repeat
      delay 1
    end repeat

    -- requires QEMU Guest Agent for query ip
    set ipList to (query ip of vm)
    set ipAddr to item 1 of ipList
    return ipAddr
  end tell
end ensure_vm

set templateName to system attribute "TEMPLATE_NAME"
set appName to system attribute "APP_NAME"
set dbName to system attribute "DB_NAME"

set appIP to ensure_vm(appName, templateName)
set dbIP to ensure_vm(dbName, templateName)

return "{\"app_ip\":\"" & appIP & "\",\"db_ip\":\"" & dbIP & "\"}"
APPLESCRIPT
)

echo "$json"