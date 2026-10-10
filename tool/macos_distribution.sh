#!/bin/bash
# Local signed archive/export; CI only compiles an unsigned validation bundle.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-archive}"
case "$mode" in
  unsigned|archive|export) ;;
  *) echo "Usage: $0 {unsigned|archive|export}" >&2; exit 2 ;;
esac

archive="build/macos/archive/Bugaoshan.xcarchive"
if [ "$mode" = export ]; then
  test -d "$archive"
  xcodebuild -exportArchive -archivePath "$archive" \
    -exportPath build/macos/appstore \
    -exportOptionsPlist macos/ExportOptions-AppStore.plist \
    -allowProvisioningUpdates
  python3 tool/verify_macos_bundle.py build/macos/appstore/Bugaoshan.pkg --package
  exit
fi

export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

args=()
if [ "$mode" = archive ]; then
  : "${MACOS_BUILD_NAME:?Set the App Store version, e.g. 2.5.3}"
  : "${MACOS_BUILD_NUMBER:?Set an unused, increasing App Store build number}"
fi
if [ -n "${MACOS_BUILD_NAME:-}" ]; then args+=(--build-name "$MACOS_BUILD_NAME"); fi
if [ -n "${MACOS_BUILD_NUMBER:-}" ]; then args+=(--build-number "$MACOS_BUILD_NUMBER"); fi
flutter build macos --release --config-only "${args[@]}" \
  --dart-define="GIT_TAG=$(git describe --tags --always --dirty)" \
  --dart-define="GIT_COMMIT=$(git rev-parse HEAD)" \
  --dart-define="GIT_COMMIT_DATE=$(git log -1 --format=%ci)" \
  --dart-define="BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
(cd macos && pod install)

if [ "$mode" = unsigned ]; then
  xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath build/macos CODE_SIGNING_ALLOWED=NO build
  python3 tool/verify_macos_bundle.py build/macos/Build/Products/Release/Bugaoshan.app
  mkdir -p build/macos/validation
  ditto -c -k --sequesterRsrc --keepParent \
    build/macos/Build/Products/Release/Bugaoshan.app \
    build/macos/validation/Bugaoshan-unsigned.zip
else
  xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath build/macos -archivePath "$archive" -allowProvisioningUpdates archive
  python3 tool/verify_macos_bundle.py "$archive/Products/Applications/Bugaoshan.app" \
    --signed --version "$MACOS_BUILD_NAME" --build "$MACOS_BUILD_NUMBER"
fi
