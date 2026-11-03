# Downloader: developer guide

Downloader is a native macOS menu-bar app written in Swift (SwiftUI + AppKit). The Xcode project is generated from `project.yml` by XcodeGen. The app runs bundled copies of yt-dlp, FFmpeg/FFprobe, and Deno as child processes; it has no Swift package dependencies.
The planning artifacts are in `openspec/changes/add-ytdlp-menubar-downloader/` (proposal, specs, design, tasks).

## Requirements

- macOS 14 or later to run; Apple Silicon (the app and the bundled FFmpeg and Deno are arm64).
- Xcode with the macOS 26 SDK or later (CI uses Xcode 26.6 on the `macos-26` runner).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

## Build and run

```bash
sh scripts/fetch-binaries.sh  # download yt-dlp, ffmpeg, ffprobe, deno into Resources/bin
scripts/build-app.sh          # xcodegen generate + Release build -> build/Downloader.app
open build/Downloader.app
```

- `scripts/fetch-binaries.sh` downloads pinned versions, checks each against a pinned SHA-256, and ad-hoc signs them. The binaries are not committed (`.gitignore`).
- `scripts/build-app.sh` reads `APP_VERSION` (`MARKETING_VERSION`) and `BUILD_NUMBER` (`CURRENT_PROJECT_VERSION`), and ad-hoc signs the whole bundle.
- To work in Xcode, run `xcodegen generate` and open `Downloader.xcodeproj` (generated, not committed).

There is no notarization and no App Store packaging.

### DMG

```bash
scripts/make-dmg.sh 0.1.0     # build/Downloader-0.1.0.dmg from build/Downloader.app
```

## Tests

```bash
xcodegen generate
xcodebuild test -project Downloader.xcodeproj -scheme DownloaderCore -destination 'platform=macOS,arch=arm64'
```

`LiveDownloadIntegrationTests` run the bundled yt-dlp against the network and are skipped unless `DOWNLOADER_RUN_INTEGRATION=1` is set (they need `Resources/bin`).

## Release

`.github/workflows/release.yml` runs on every push to `main` that changes `Sources/`, `Tests/`, `Resources/`, `project.yml`, `scripts/`, or the workflow itself (and on manual dispatch). It installs XcodeGen, fetches the binaries, runs the tests, builds the app, packages a DMG, publishes a GitHub release `v<version>`, and deletes all older releases and their tags.

The version keeps `project.yml`'s `MARKETING_VERSION` major.minor and raises the patch (`scripts/next-version.sh`).

## Project layout

```
Sources/
  DownloaderCore/   framework: models, settings, history, download queue, yt-dlp command builder,
                    progress parser, process runner, binary locator
  Downloader/       app: status item, window, SwiftUI views (Downloads, History, Settings)
Tests/
  DownloaderCoreTests/  unit tests, plus opt-in live integration tests
Resources/bin/      bundled binaries (fetched, not committed), README.md, THIRD_PARTY_NOTICES.md
scripts/            fetch-binaries.sh, build-app.sh, make-dmg.sh, next-version.sh
design/             interface mock-up
docs/               README images
project.yml         XcodeGen spec
```

## Dependencies

There are no Swift package dependencies (`project.yml` declares no `packages:`) and no vendored third-party source code.

### Bundled programs

Copied unmodified into `Downloader.app/Contents/Resources/bin/` and run as separate processes. Versions are pinned in `scripts/fetch-binaries.sh`.

| Program | Version | License | Commercial use | Source |
|---|---|---|---|---|
| yt-dlp (`yt-dlp_macos`, PyInstaller build) | 2026.10.21 | yt-dlp itself is [Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE). Per the [yt-dlp README](https://github.com/yt-dlp/yt-dlp#release-files), the PyInstaller-bundled executables include GPLv3+ code, so the combined work is GPLv3+ | Allowed | [github.com/yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp) |
| FFmpeg (`ffmpeg`, `ffprobe`), static arm64 build by Martin Riedl | 8.1.2 | GPL version 3 (`--enable-gpl --enable-version3`, no `--enable-nonfree`) | Allowed | [ffmpeg.org](https://ffmpeg.org/download.html), [build script](https://git.martin-riedl.de/ffmpeg/build-script), [binaries](https://ffmpeg.martin-riedl.de) |
| Deno | 2.9.8 | [MIT](https://github.com/denoland/deno/blob/main/LICENSE.md) | Allowed | [github.com/denoland/deno](https://github.com/denoland/deno) |

Notes:

- GPL permits selling and commercial distribution ([GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.html#DoesTheGPLAllowMoney)). It requires that anyone who distributes the binaries also makes the exactly corresponding source available, as easy to access as the binaries ([GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.html#AnonFTPAndSendSources), GPLv3 section 6(d)).
- The app talks to these programs only through command-line arguments and pipes. The FSF considers such programs normally separate programs that may be distributed together as an aggregate, even under different licenses ([GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.html#MereAggregation)); it also notes that the final line is a legal question. On that basis the app's own code is MIT-licensed.
- FFmpeg's distribution checklist: [ffmpeg.org/legal.html](https://ffmpeg.org/legal.html).

### Toolchain and build tools

| Component | Use | License | Open source |
|---|---|---|---|
| [Swift](https://www.swift.org/) compiler and standard library | Language (Swift 5 mode) | [Apache 2.0 with Runtime Library Exception](https://www.swift.org/legal/license.html) | Yes |
| [Xcode](https://developer.apple.com/xcode/) and the macOS SDK | `xcodebuild`, SDK, XCTest | [Xcode and Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf) | No |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | Generates `Downloader.xcodeproj` from `project.yml` | MIT | Yes |
| `codesign`, `diskutil`, `shasum`, `curl`, `unzip` (macOS) | Signing, DMG creation, binary fetching | Part of macOS | — |
| zsh, sh | Build scripts | [Berkeley-style](https://zsh.sourceforge.io/FAQ/zshfaq01.html) (zsh) | Yes |
| [actions/checkout](https://github.com/actions/checkout) v7.0.1 | Check out the repository in CI | [MIT](https://github.com/actions/checkout/blob/main/LICENSE) | Yes |
| [GitHub CLI](https://github.com/cli/cli) (`gh`) | Create and prune releases in CI | [MIT](https://github.com/cli/cli/blob/trunk/LICENSE) | Yes |
| [Homebrew](https://brew.sh/) | Installs XcodeGen in CI | BSD 2-Clause | Yes |
| GitHub-hosted runner `macos-26` | CI machine | [GitHub Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service) | No |

### Apple frameworks (macOS SDK)

All are covered by the [Xcode and Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf).

| Framework | Used for |
|---|---|
| [SwiftUI](https://developer.apple.com/documentation/swiftui) | Window content: Downloads, History, Settings |
| [AppKit](https://developer.apple.com/documentation/appkit) | Status item, window, folder picker |
| [Foundation](https://developer.apple.com/documentation/foundation) | Processes, files, JSON, settings |
| [Combine](https://developer.apple.com/documentation/combine) | Observable state |
| [XCTest](https://developer.apple.com/documentation/xctest) | Unit and integration tests |
