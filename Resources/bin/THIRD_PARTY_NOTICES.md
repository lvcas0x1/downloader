# Third-party components

Downloader bundles the following programs unmodified in `Contents/Resources/bin/`
and runs them as separate processes. Versions are pinned in
`scripts/fetch-binaries.sh`.

| Component | Version | License | Source |
|---|---|---|---|
| yt-dlp (`yt-dlp_macos`) | 2026.10.21 | Unlicense | https://github.com/yt-dlp/yt-dlp |
| FFmpeg (`ffmpeg`, `ffprobe`), static arm64 build by Martin Riedl | 8.1.2 | GPL version 3 (built with `--enable-gpl --enable-version3`) | FFmpeg: https://ffmpeg.org/download.html — build script and configuration: https://git.martin-riedl.de/ffmpeg/build-script — binaries: https://ffmpeg.martin-riedl.de |
| Deno | 2.9.8 | MIT | https://github.com/denoland/deno |

The GNU General Public License version 3 is available at
https://www.gnu.org/licenses/gpl-3.0.html.
