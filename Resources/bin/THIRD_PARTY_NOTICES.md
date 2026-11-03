# Third-party components

Downloader bundles the following programs in `Contents/Resources/bin/` and runs them
as separate processes. Downloader's own source code is MIT-licensed; these programs
keep their own licenses. Full license texts are in `licenses/` next to this file.
Versions are pinned in `scripts/fetch-binaries.sh` and `scripts/build-ffmpeg.sh`.

| Component | Version | License | License texts |
|---|---|---|---|
| yt-dlp (`yt-dlp_macos`, unmodified official build) | 2026.10.21 | yt-dlp itself is Unlicense. The PyInstaller build also contains third-party code, including mutagen (GPL-2.0-or-later), so the build as a whole is GPL-3.0-or-later | `licenses/yt-dlp-LICENSE`, `licenses/yt-dlp-THIRD_PARTY_LICENSES.txt`, `licenses/GPL-3.0.txt` |
| FFmpeg (`ffmpeg`, `ffprobe`), built from unmodified source by `scripts/build-ffmpeg.sh` | 9.0.2 | LGPL-2.1-or-later (no `--enable-gpl`, no `--enable-nonfree`) | `licenses/FFmpeg-COPYING.LGPLv2.1`, `licenses/FFmpeg-LICENSE.md` |
| LAME (statically linked into `ffmpeg` and `ffprobe` for MP3 encoding) | 4.0 | LGPL-2.0-or-later (GNU Library General Public License version 2) | `licenses/LAME-COPYING` |
| Deno (unmodified official build) | 2.9.8 | MIT | `licenses/Deno-LICENSE.md` |

## Corresponding source

Every GitHub release of Downloader publishes, next to the DMG, the source of the GPL and
LGPL programs in that DMG:

- `yt-dlp-<version>-source.tar.gz`: yt-dlp at the release tag, including the build
  scripts (`bundle/pyinstaller.py`, `.github/workflows/build.yml`) and the pinned,
  hash-checked dependency list of the macOS build (`bundle/requirements/macos.txt`).
  The pinned dependencies are published by their projects on PyPI (https://pypi.org)
  and python.org (https://www.python.org/downloads/source/).
- `ffmpeg-<version>.tar.xz` and `lame-<version>.tar.gz`: the official source releases.
- `build-ffmpeg.sh`: the exact configuration used to build `ffmpeg` and `ffprobe`.

Releases: https://github.com/lvcas0x1/downloader/releases

Upstream projects:

- yt-dlp: https://github.com/yt-dlp/yt-dlp
- FFmpeg: https://ffmpeg.org (source releases: https://ffmpeg.org/releases/)
- LAME: https://lame.sourceforge.io
- Deno: https://github.com/denoland/deno
