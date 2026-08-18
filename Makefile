.PHONY: generate build run dist

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme Whitebored -destination 'platform=macOS,arch=arm64' -derivedDataPath .build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual AD_HOC_CODE_SIGNING_ALLOWED=YES

run: build
	open .build/Build/Products/Debug/Whitebored.app

dist:
	./scripts/package.sh
