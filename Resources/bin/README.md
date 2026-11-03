# Bundled binaries

The app loads `yt-dlp`, `ffmpeg`, `ffprobe`, and `deno` from this directory inside
the app bundle (`Contents/Resources/bin/`), resolved by `BinaryLocator`. It never
uses a system-installed copy.

Fetch the pinned, checksum-verified, ad-hoc-signed executables before building:

```
sh scripts/fetch-binaries.sh
```

```
Resources/bin/yt-dlp     # official universal macOS build
Resources/bin/ffmpeg     # static arm64 build
Resources/bin/ffprobe    # same build as ffmpeg; required by audio-only (-x)
Resources/bin/deno       # official release; JS runtime for YouTube (yt-dlp wiki: EJS)
```

`--ffmpeg-location` is passed this directory, so yt-dlp finds both ffmpeg and
ffprobe. Versions and licenses: `THIRD_PARTY_NOTICES.md`.

The executables are not committed (see `.gitignore`). For distribution they must
be covered by the app's Developer ID signing and notarization (task 1.4).
