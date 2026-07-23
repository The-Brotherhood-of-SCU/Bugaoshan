#!/usr/bin/env bash

set -euo pipefail

readonly bundle_id="io.github.thebrotherhoodofscu.bugaoshan"
readonly app_path="build/ios/iphoneos/Runner.app"

usage() {
  cat <<'EOF'
Usage: tool/install_ios_profile.sh <device> [--no-build]

Build and install the iOS Profile app on a connected physical device.
<device> may be a CoreDevice identifier, UDID, or device name.

Options:
  --no-build  Reuse build/ios/iphoneos/Runner.app.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 64
fi

readonly device="$1"
readonly build_option="${2:-}"
if [[ -n "$build_option" && "$build_option" != "--no-build" ]]; then
  usage >&2
  exit 64
fi

for command in flutter xcrun python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing required command: $command" >&2
    exit 69
  fi
done

if [[ "$build_option" != "--no-build" ]]; then
  flutter build ios --profile
fi

if [[ ! -d "$app_path" ]]; then
  echo "Profile app not found at $app_path" >&2
  echo "Run without --no-build to create it first." >&2
  exit 66
fi

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bugaoshan-ios-profile.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

apps_json="$temp_dir/apps.json"
processes_json="$temp_dir/processes.json"

# devicectl may keep the old executable alive while replacing its app bundle.
# Resolve the currently installed bundle path and stop every process inside it
# before installing, including WidgetKit extensions.
xcrun devicectl device info apps \
  --device "$device" \
  --json-output "$apps_json" >/dev/null

installed_path="$({
  python3 - "$apps_json" "$bundle_id" <<'PY'
import json
import sys
from urllib.parse import unquote, urlparse

with open(sys.argv[1], encoding="utf-8") as source:
    apps = json.load(source)["result"]["apps"]

for app in apps:
    if app.get("bundleIdentifier") == sys.argv[2]:
        print(unquote(urlparse(app["url"]).path).rstrip("/"))
        break
PY
} || true)"

if [[ -n "$installed_path" ]]; then
  xcrun devicectl device info processes \
    --device "$device" \
    --json-output "$processes_json" >/dev/null

  running_pids="$({
    python3 - "$processes_json" "$installed_path" <<'PY'
import json
import sys
from urllib.parse import unquote, urlparse

with open(sys.argv[1], encoding="utf-8") as source:
    processes = json.load(source)["result"]["runningProcesses"]

prefix = sys.argv[2].rstrip("/") + "/"
for process in processes:
    executable = unquote(urlparse(process.get("executable", "")).path)
    if executable.startswith(prefix):
        print(process["processIdentifier"])
PY
  } || true)"

  for pid in $running_pids; do
    echo "Stopping existing process $pid before installation..."
    if ! xcrun devicectl device process terminate \
      --device "$device" \
      --pid "$pid" >/dev/null; then
      echo "Warning: process $pid exited before it could be stopped." >&2
    fi
  done
fi

xcrun devicectl device install app --device "$device" "$app_path"

if ! xcrun devicectl device --timeout 15 process launch \
  --device "$device" \
  "$bundle_id"; then
  cat >&2 <<'EOF'

The app was installed, but iOS did not finish launching it within 15 seconds.
Unlock the device and try opening the app. If it remains blank, reboot the
device once to clear stale LaunchServices/Scene state, then rerun with
--no-build.
EOF
  exit 1
fi

