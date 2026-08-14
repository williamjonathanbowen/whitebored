#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is missing. brew install xcodegen"
  exit 1
fi

xcodegen generate
xcodebuild -scheme Whitebored -destination 'platform=macOS,arch=arm64' -derivedDataPath .build \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual AD_HOC_CODE_SIGNING_ALLOWED=YES
open .build/Build/Products/Debug/Whitebored.app
