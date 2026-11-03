#!/bin/sh
# Fetch the pinned bundled binaries into Resources/bin, verify each download against
# the SHA-256 pinned below (taken from each publisher's checksum file), and ad-hoc
# sign them (arm64 requires at least an ad-hoc signature to execute).
#
#   yt-dlp           official universal macOS build   https://github.com/yt-dlp/yt-dlp
#   ffmpeg, ffprobe  static arm64 builds              https://ffmpeg.martin-riedl.de
#                    (audio-only `-x` needs both)
#   deno             official release                 https://github.com/denoland/deno
#                    (JS runtime for YouTube: https://github.com/yt-dlp/yt-dlp/wiki/EJS)
#
# Usage: sh scripts/fetch-binaries.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/Resources/bin"
mkdir -p "$BIN"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

YTDLP_VERSION="2026.10.21"
YTDLP_SHA256="7a6fe71d7d680f1fb0ac18d4949873d77db2859e90017c0f44bd94b23be4ee40" # yt-dlp_macos
FFMPEG_BUILD="1783011502_8.1.2"
FFMPEG_SHA256="ef1aa60006c7b77ce170c1608c08d8e4ba1c30c5746f2ac986ded932d0ac2c3c"  # ffmpeg.zip
FFPROBE_SHA256="c39787f4af7a3932502d2d48db6f6feaaa836b48a73ef78c32cc3285df61dfaf" # ffprobe.zip
DENO_VERSION="v2.9.8"
DENO_SHA256="9f0bf660393da2eaff044cdc7444cb08c73f235849b61d224d825a194ce7c98e"   # deno-aarch64-apple-darwin.zip

# fetch <url> <file> <sha256>
fetch() {
  echo "==> $1"
  curl -fsSL --retry 3 -o "$2" "$1"
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

for tool in ffmpeg ffprobe; do
  if [ "$tool" = ffmpeg ]; then sum="$FFMPEG_SHA256"; else sum="$FFPROBE_SHA256"; fi
  fetch "https://ffmpeg.martin-riedl.de/download/macos/arm64/$FFMPEG_BUILD/$tool.zip" \
    "$TMP/$tool.zip" "$sum"
  unzip -o -q "$TMP/$tool.zip" -d "$TMP/$tool"
  install_bin "$TMP/$tool/$tool" "$tool"
done

fetch "https://github.com/denoland/deno/releases/download/$DENO_VERSION/deno-aarch64-apple-darwin.zip" \
  "$TMP/deno.zip" "$DENO_SHA256"
unzip -o -q "$TMP/deno.zip" -d "$TMP/deno"
install_bin "$TMP/deno/deno" deno

echo "Done. Re-build the app so the binaries are copied into Downloader.app."
