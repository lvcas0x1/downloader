#!/bin/sh
# Fetch the pinned bundled binaries into Resources/bin, verify each download against
# the SHA-256 pinned below (taken from each publisher's checksum file), and ad-hoc
# sign them (arm64 requires at least an ad-hoc signature to execute).
#
#   yt-dlp           official universal macOS build   https://github.com/yt-dlp/yt-dlp
#   deno             official release                 https://github.com/denoland/deno
#                    (JS runtime for YouTube: https://github.com/yt-dlp/yt-dlp/wiki/EJS)
#   ffmpeg, ffprobe  built from source by scripts/build-ffmpeg.sh (audio-only `-x` needs both)
#
# Also saves the yt-dlp source at the same tag to build/sources/ for the release: the
# yt-dlp_macos build is GPLv3+ (it bundles GPL code), so its source is published with it.
#
# Usage: sh scripts/fetch-binaries.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/Resources/bin"
SOURCES="$ROOT/build/sources"
mkdir -p "$BIN" "$SOURCES"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

YTDLP_VERSION="2026.10.21"
YTDLP_SHA256="7a6fe71d7d680f1fb0ac18d4949873d77db2859e90017c0f44bd94b23be4ee40" # yt-dlp_macos
DENO_VERSION="v2.9.8"
DENO_SHA256="9f0bf660393da2eaff044cdc7444cb08c73f235849b61d224d825a194ce7c98e"   # deno-aarch64-apple-darwin.zip

# fetch <url> <file> <sha256>
fetch() {
  echo "==> $1"
  curl -fsSL --retry 3 --retry-all-errors -o "$2" "$1"
  actual="$(shasum -a 256 "$2" | cut -d' ' -f1)"
  [ "$actual" = "$3" ] || { echo "checksum mismatch for $1: $actual" >&2; exit 1; }
}

# install <file> <name>
install_bin() {
  mv "$1" "$BIN/$2"
  chmod +x "$BIN/$2"
  codesign --force --sign - "$BIN/$2"
}

fetch "https://github.com/yt-dlp/yt-dlp/releases/download/$YTDLP_VERSION/yt-dlp_macos" \
  "$TMP/yt-dlp" "$YTDLP_SHA256"
install_bin "$TMP/yt-dlp" yt-dlp

# The tag archive includes the PyInstaller build scripts and the pinned, hash-checked
# dependency list of the macOS build (bundle/requirements/macos.txt). GitHub generates it
# on request, so it is not pinned to a checksum; it is only republished, never executed.
echo "==> yt-dlp $YTDLP_VERSION source"
curl -fsSL --retry 3 --retry-all-errors -o "$SOURCES/yt-dlp-$YTDLP_VERSION-source.tar.gz" \
  "https://github.com/yt-dlp/yt-dlp/archive/refs/tags/$YTDLP_VERSION.tar.gz"

fetch "https://github.com/denoland/deno/releases/download/$DENO_VERSION/deno-aarch64-apple-darwin.zip" \
  "$TMP/deno.zip" "$DENO_SHA256"
unzip -o -q "$TMP/deno.zip" -d "$TMP/deno"
install_bin "$TMP/deno/deno" deno

sh "$ROOT/scripts/build-ffmpeg.sh"

echo "Done. Re-build the app so the binaries are copied into Downloader.app."
