#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is missing. brew install xcodegen"
  exit 1
fi

xcodegen generate
xcodebuild -scheme Whitebored -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual AD_HOC_CODE_SIGNING_ALLOWED=YES

APP=".build/Build/Products/Release/Whitebored.app"
BIN="$APP/Contents/MacOS/Whitebored"
ZIP="web/public/whitebored.zip"

if ! test -x "$BIN"; then
  echo "missing built app at $APP"
  exit 1
fi

if strings "$BIN" | grep -E 'sk-ant-|sk-proj-|sk-svcacct-'; then
  echo "refusing to zip: looks like an api key is inside the app"
  exit 1
fi

for name in ANTHROPIC_API_KEY OPENAI_API_KEY; do
  value="${(P)name:-}"
  if [[ -n "$value" ]] && grep -a -F -- "$value" "$BIN" >/dev/null; then
    echo "refusing to zip: $name leaked into the app"
    exit 1
  fi
done

if find "$APP" -iname '*key*' | grep -q .; then
  echo "refusing to zip: found a key-named file inside the app"
  find "$APP" -iname '*key*'
  exit 1
fi

mkdir -p web/public
rm -f "$ZIP"
ditto -c -k --keepParent --norsrc --noextattr --noacl "$APP" "$ZIP"
echo "wrote $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"
