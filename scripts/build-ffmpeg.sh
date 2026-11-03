#!/bin/sh
# Build ffmpeg and ffprobe for Resources/bin from the official source releases, as an
# LGPL build (no --enable-gpl, no --enable-nonfree) with LAME for MP3 encoding.
#
#   FFmpeg  https://ffmpeg.org/releases/      LGPL-2.1-or-later
#   LAME    https://lame.sourceforge.io/      LGPL-2.0-or-later (Library GPL v2)
#
# Static arm64 executables; they link only to macOS system libraries and frameworks.
# The downloaded source archives are kept in build/sources/ so a release can publish
# them next to the app (the Corresponding Source of the bundled ffmpeg and ffprobe).
#
# Usage: sh scripts/build-ffmpeg.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/Resources/bin"
SOURCES="$ROOT/build/sources"
WORK="$ROOT/build/ffmpeg-build"

FFMPEG_VERSION="9.0.2"
FFMPEG_SHA256="8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e"
LAME_VERSION="4.0"
LAME_SHA256="3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb"

# Same minimum as the app (project.yml deploymentTarget).
export MACOSX_DEPLOYMENT_TARGET="14.0"
JOBS="$(sysctl -n hw.ncpu)"

# fetch <url> <file> <sha256>
fetch() {
  if [ ! -f "$2" ]; then
    echo "==> $1"
    curl -fsSL --retry 3 --retry-all-errors -o "$2.tmp" "$1"
    mv "$2.tmp" "$2"
  fi
  actual="$(shasum -a 256 "$2" | cut -d' ' -f1)"
  [ "$actual" = "$3" ] || { echo "checksum mismatch for $2: $actual" >&2; rm -f "$2"; exit 1; }
}

mkdir -p "$BIN" "$SOURCES"
rm -rf "$WORK"
mkdir -p "$WORK/prefix"

fetch "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" \
  "$SOURCES/ffmpeg-$FFMPEG_VERSION.tar.xz" "$FFMPEG_SHA256"
fetch "https://downloads.sourceforge.net/project/lame/lame/$LAME_VERSION/lame-$LAME_VERSION.tar.gz" \
  "$SOURCES/lame-$LAME_VERSION.tar.gz" "$LAME_SHA256"
# The build recipe is part of the Corresponding Source.
cp "$0" "$SOURCES/build-ffmpeg.sh"

echo "==> LAME $LAME_VERSION"
tar -xzf "$SOURCES/lame-$LAME_VERSION.tar.gz" -C "$WORK"
(
  cd "$WORK/lame-$LAME_VERSION"
  ./configure --prefix="$WORK/prefix" --enable-static --disable-shared \
    --disable-frontend --disable-decoder --disable-dependency-tracking >/dev/null
  make -j"$JOBS" >/dev/null
  make install >/dev/null
)

echo "==> FFmpeg $FFMPEG_VERSION"
tar -xJf "$SOURCES/ffmpeg-$FFMPEG_VERSION.tar.xz" -C "$WORK"
(
  cd "$WORK/ffmpeg-$FFMPEG_VERSION"
  # --disable-autodetect keeps Homebrew or other non-system libraries out of the build;
  # everything enabled below is a macOS system library or framework, plus LAME.
  ./configure \
    --prefix="$WORK/prefix" \
    --arch=arm64 \
    --enable-static --disable-shared \
    --disable-autodetect \
    --enable-pthreads --enable-zlib --enable-bzlib --enable-iconv \
    --enable-securetransport --enable-audiotoolbox --enable-videotoolbox \
    --enable-libmp3lame \
    --disable-ffplay --disable-doc --disable-debug \
    --extra-cflags="-I$WORK/prefix/include" \
    --extra-ldflags="-L$WORK/prefix/lib" \
    --extra-libs="-liconv" >/dev/null
  make -j"$JOBS" >/dev/null
)

for tool in ffmpeg ffprobe; do
  cp "$WORK/ffmpeg-$FFMPEG_VERSION/$tool" "$BIN/$tool"
  chmod +x "$BIN/$tool"
  codesign --force --sign - "$BIN/$tool"
done

"$BIN/ffmpeg" -hide_banner -version | head -3
echo "Built $BIN/ffmpeg and $BIN/ffprobe"
