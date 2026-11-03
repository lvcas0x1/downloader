# Bundled binaries

The app loads `yt-dlp`, `ffmpeg`, `ffprobe`, and `deno` from this directory inside
the app bundle (`Contents/Resources/bin/`), resolved by `BinaryLocator`. It never
uses a system-installed copy.

Fetch the pinned, checksum-verified executables and build ffmpeg before building
the app (all are ad-hoc signed):

```
sh scripts/fetch-binaries.sh
```

```
Resources/bin/yt-dlp     # official universal macOS build
Resources/bin/ffmpeg     # built from source by scripts/build-ffmpeg.sh (LGPL, with LAME)
Resources/bin/ffprobe    # same build as ffmpeg; required by audio-only (-x)
Resources/bin/deno       # official release; JS runtime for YouTube (yt-dlp wiki: EJS)
Resources/bin/licenses/  # license texts of the bundled programs (committed)
```

`--ffmpeg-location` is passed this directory, so yt-dlp finds both ffmpeg and
ffprobe. Versions, licenses, and where the source is published: `THIRD_PARTY_NOTICES.md`.

The executables are not committed (see `.gitignore`); `licenses/` and these two
Markdown files are. When a version changes, update `licenses/` and
`THIRD_PARTY_NOTICES.md` with it. For distribution they must
be covered by the app's Developer ID signing and notarization (task 1.4).
