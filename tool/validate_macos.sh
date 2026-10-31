#!/bin/bash
# Compile and verify a credential-free universal app for PR validation.
set -euo pipefail
cd "$(dirname "$0")/.."

export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

args=(--release --config-only)
if [ -n "${MACOS_BUILD_NAME:-}" ]; then args+=(--build-name "$MACOS_BUILD_NAME"); fi
if [ -n "${MACOS_BUILD_NUMBER:-}" ]; then args+=(--build-number "$MACOS_BUILD_NUMBER"); fi
flutter build macos "${args[@]}" \
  --dart-define="GIT_TAG=$(git describe --tags --always --dirty)" \
  --dart-define="GIT_COMMIT=$(git rev-parse HEAD)" \
  --dart-define="GIT_COMMIT_DATE=$(git log -1 --format=%ci)" \
  --dart-define="BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
(cd macos && pod install)

  xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath build/macos CODE_SIGNING_ALLOWED=NO build
  python3 tool/verify_macos_bundle.py build/macos/Build/Products/Release/不高山上.app
  mkdir -p build/macos/validation
  ditto -c -k --sequesterRsrc --keepParent \
    build/macos/Build/Products/Release/不高山上.app \
    build/macos/validation/Bugaoshan-unsigned.zip