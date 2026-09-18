#!/usr/bin/env bash
set -euo pipefail

# Run from repository root after pub get, code generation and gen-l10n.
# This uses newly created simulators only; no physical devices or credentials.
capture_tools="$(cd "$(dirname "$0")" && pwd)"
capture_root="$PWD/build/appstore"
mkdir -p "$capture_root/screenshots" "$capture_root/logs"
xcodebuild -version > "$capture_root/logs/xcode-version.txt"
xcrun simctl list -j > "$capture_root/logs/simulator-inventory.json"
runtime_id="$(python3 - "$capture_root/logs/simulator-inventory.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
available=[r for r in data['runtimes'] if r.get('isAvailable') and '.iOS-' in r['identifier'] and int(r['version'].split('.')[0])>=17]
if not available: raise SystemExit('No available iOS >=17 simulator runtime; install one before capturing.')
print(max(available,key=lambda r:tuple(map(int,r['version'].split('.'))))['identifier'])
PY
)"

for family in iphone ipad; do
  if [ "$family" = iphone ]; then
    model='com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max'
  else
    model='com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-16GB'
    # Installed Xcode versions may name the same 13-inch model without RAM.
    model="$(python3 - "$capture_root/logs/simulator-inventory.json" <<'PY'
import json,sys
types=json.load(open(sys.argv[1]))['devicetypes']
matches=[d['identifier'] for d in types if d['name'].startswith('iPad Pro 13-inch (M4)')]
if not matches: raise SystemExit('iPad Pro 13-inch (M4) device type is unavailable')
print(matches[0])
PY
)"
  fi
  simulator_id="$(xcrun simctl create "Bugaoshan Store $family" "$model" "$runtime_id")"
  trap 'xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true; xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true' EXIT
  xcrun simctl boot "$simulator_id"
  xcrun simctl bootstatus "$simulator_id" -b
  xcrun simctl ui "$simulator_id" appearance light
  xcrun simctl status_bar "$simulator_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
  SCREENSHOT_SIMULATOR_ID="$simulator_id" SCREENSHOT_OUTPUT="$capture_root/screenshots/$family" \
    flutter drive --debug --no-pub --target "$capture_tools/capture_main.dart" \
    --driver "$capture_tools/capture_driver.dart" --device-id "$simulator_id" \
    2>&1 | tee "$capture_root/logs/$family-driver.log"
  xcrun simctl shutdown "$simulator_id"
  xcrun simctl delete "$simulator_id"
  trap - EXIT
done

# Lossless PNG remains unchanged if opaque. Alpha PNGs are converted by sips
# to full-quality JPEG without cropping, resizing or replacing any UI pixels.
python3 - "$capture_root/screenshots" <<'PY'
import pathlib,struct,subprocess,sys,json
root=pathlib.Path(sys.argv[1])
expected={'iphone':(1320,2868),'ipad':(2064,2752)}
report=[]
for family,size in expected.items():
 files=sorted((root/family).glob('0*.png'))
 if len(files)!=3: raise SystemExit(f'{family}: expected three successful captures, got {len(files)}')
 for path in files:
  data=path.read_bytes()
  width,height=struct.unpack('>II',data[16:24])
  if (width,height)!=size: raise SystemExit(f'{path}: unexpected image dimensions {width}x{height}')
  if data[25] in (4,6):
   converted=path.with_suffix('.jpg')
   subprocess.run(['sips','-s','format','jpeg','-s','formatOptions','100',str(path),'--out',str(converted)],check=True)
   path.unlink()
   path=converted
  report.append({'file':str(path.relative_to(root)),'width':width,'height':height,'source':'native iOS Simulator screenshot; fictional local course data'})
(root/'capture-manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
PY
