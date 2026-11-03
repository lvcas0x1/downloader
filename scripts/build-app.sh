#!/bin/zsh
# Build build/Downloader.app (Release, Apple Silicon) with its bundled binaries, ad-hoc signed.
# Env: APP_VERSION (default: project.yml MARKETING_VERSION), BUILD_NUMBER (default: project.yml).
# Usage: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

for bin in yt-dlp ffmpeg ffprobe deno; do
  [[ -x Resources/bin/$bin ]] || { echo "missing Resources/bin/$bin: run scripts/fetch-binaries.sh"; exit 1; }
done

xcodegen generate --quiet

args=(-project Downloader.xcodeproj -scheme Downloader -configuration Release
      -derivedDataPath build/dd -destination 'generic/platform=macOS' ARCHS=arm64)
[[ -n "${APP_VERSION:-}" ]] && args+=(MARKETING_VERSION="$APP_VERSION")
[[ -n "${BUILD_NUMBER:-}" ]] && args+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
xcodebuild "${args[@]}" -quiet build

rm -rf build/Downloader.app
cp -R build/dd/Build/Products/Release/Downloader.app build/
# Re-sign the whole bundle so the nested binaries and framework share one ad-hoc signature.
codesign --force --deep --sign - build/Downloader.app
codesign --verify --deep --strict build/Downloader.app
echo build/Downloader.app
