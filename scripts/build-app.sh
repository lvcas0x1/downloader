#!/bin/zsh
# Build build/Downloader.app (Release, Apple Silicon) with its bundled binaries and Sparkle.framework,
# signed with the "Downloader Code Signing" identity when available.
# Env: APP_VERSION (default: project.yml MARKETING_VERSION), BUILD_NUMBER (default: project.yml), SIGN_IDENTITY.
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

APP=build/Downloader.app
rm -rf "$APP"
ditto build/dd/Build/Products/Release/Downloader.app "$APP"

# Sparkle's XPC services are only needed by sandboxed apps
# (https://sparkle-project.org/documentation/sandboxing/).
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$SPARKLE/Versions/B/XPCServices" "$SPARKLE/XPCServices"

# Sign everything with the "Downloader Code Signing" self-signed identity (the same one locally and
# in CI), inside-out and without --deep, so every release keeps the same designated requirement.
IDENTITY="${SIGN_IDENTITY:-Downloader Code Signing}"
if ! security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  echo "warning: identity '$IDENTITY' not found; using ad-hoc signing"
  IDENTITY="-"
fi
for bin in "$APP"/Contents/Resources/bin/{yt-dlp,ffmpeg,ffprobe,deno}; do
  codesign --force --sign "$IDENTITY" "$bin"
done
codesign --force --sign "$IDENTITY" "$SPARKLE/Versions/B/Autoupdate"
codesign --force --sign "$IDENTITY" "$SPARKLE/Versions/B/Updater.app"
codesign --force --sign "$IDENTITY" "$SPARKLE"
codesign --force --sign "$IDENTITY" "$APP/Contents/Frameworks/DownloaderCore.framework"
codesign --force --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
