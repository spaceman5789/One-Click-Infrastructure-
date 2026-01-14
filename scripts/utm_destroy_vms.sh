#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-app-vm}"
DB_NAME="${DB_NAME:-db-vm}"

 /usr/bin/osascript <<'APPLESCRIPT'
on stop_and_delete(vmName)
  tell application "UTM"
    try
      set vm to virtual machine named vmName
      try
        stop vm by force
      end try
      delete vm
    end try
  end tell
end stop_and_delete

set appName to system attribute "APP_NAME"
set dbName to system attribute "DB_NAME"

stop_and_delete(appName)
stop_and_delete(dbName)
APPLESCRIPT