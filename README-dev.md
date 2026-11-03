# Downloader: developer guide

Downloader is a native macOS menu-bar app written in Swift (SwiftUI + AppKit). The Xcode project is generated from `project.yml` by XcodeGen. The app runs bundled copies of yt-dlp, FFmpeg/FFprobe, and Deno as child processes; its only Swift package is [Sparkle](https://sparkle-project.org/) for in-app updates.
The planning artifacts are in `openspec/changes/add-ytdlp-menubar-downloader/` (proposal, specs, design, tasks).

## Requirements

- macOS 14 or later to run; Apple Silicon (the app and the bundled FFmpeg and Deno are arm64).
- Xcode with the macOS 26 SDK or later (CI uses Xcode 26.6 on the `macos-26` runner).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

## Build and run

```bash
sh scripts/fetch-binaries.sh  # download yt-dlp and deno, build ffmpeg and ffprobe, into Resources/bin
scripts/build-app.sh          # xcodegen generate + Release build -> build/Downloader.app
open build/Downloader.app
```

- `scripts/fetch-binaries.sh` downloads pinned versions of yt-dlp and Deno, checks each against a pinned SHA-256, ad-hoc signs them (the app build re-signs them), saves the yt-dlp source to `build/sources/`, and runs `scripts/build-ffmpeg.sh`. The binaries are not committed (`.gitignore`).
- `scripts/build-ffmpeg.sh` builds `ffmpeg` and `ffprobe` (about a minute on Apple Silicon) from the official FFmpeg and LAME source releases, checked against pinned SHA-256s: an LGPL build (no `--enable-gpl`, no `--enable-nonfree`) with `--disable-autodetect`, so the executables link only to macOS system libraries. The source archives and the script are kept in `build/sources/`.
- `scripts/build-app.sh` reads `APP_VERSION` (`MARKETING_VERSION`), `BUILD_NUMBER` (`CURRENT_PROJECT_VERSION`), and `SIGN_IDENTITY`, removes Sparkle's XPC services, and signs the bundle inside-out (bundled programs, Sparkle, DownloaderCore, app).
- To work in Xcode, run `xcodegen generate` and open `Downloader.xcodeproj` (generated, not committed).

### Signing

The app is signed with a self-signed certificate, **Downloader Code Signing** (valid until 2036-10-31), so every build has the same designated requirement (`identifier "com.lvcas0x1.downloader" and certificate leaf = H"0fb144bd…"`).

- **Local builds:** `scripts/build-app.sh` uses the identity from your login keychain and falls back to ad-hoc signing with a warning when it is missing.
- **CI:** the same certificate is imported from the `SIGNING_CERTIFICATE_P12` and `SIGNING_CERTIFICATE_PASSWORD` secrets into a temporary keychain.
- The hardened runtime is off (`project.yml`): with a self-signed certificate (no Team ID), library validation would reject the embedded frameworks.

Keep a backup of the certificate (with its private key) outside the keychain.

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

`.github/workflows/release.yml` runs on every push to `main` that changes `Sources/`, `Tests/`, `Resources/`, `project.yml`, `scripts/`, or the workflow itself (and on manual dispatch). It installs XcodeGen, fetches yt-dlp and Deno, builds FFmpeg, runs the tests, imports the signing certificate, builds and signs the app, packages a DMG, writes the Sparkle update feed, publishes a GitHub release `v<version>` with the DMG, `appcast.xml`, and every file in `build/sources/` (the source of the bundled GPL/LGPL programs), and deletes all older releases and their tags.

The version keeps `project.yml`'s `MARKETING_VERSION` major.minor and raises the patch (`scripts/next-version.sh`).

### In-app updates (Sparkle)

- The app reads the feed from `SUFeedURL` = `https://github.com/lvcas0x1/downloader/releases/latest/download/appcast.xml`. Only the newest release is kept, so this URL always points to the current feed.
- `scripts/make-appcast.sh` writes `build/appcast.xml` with the DMG's EdDSA signature from Sparkle's `sign_update`. In CI the private key comes from the `SPARKLE_ED_PRIVATE_KEY` secret; locally it is read from the login keychain (account `dev.lvcas0x1.downloader`). The public key is `SUPublicEDKey` in `project.yml`.
- Sparkle installs an update only if its EdDSA signature matches `SUPublicEDKey`. If the private key is lost, existing installs cannot be updated any more, so keep a backup of it.
- `CURRENT_PROJECT_VERSION` (`CFBundleVersion`) is the workflow run number, so every release has a higher build number, which Sparkle uses to compare versions.
- Automatic checks are on (`SUEnableAutomaticChecks`); the menu-bar menu also has **Update**.

## Project layout

```
Sources/
  DownloaderCore/   framework: models, settings, history, download queue, yt-dlp command builder,
                    progress parser, process runner, binary locator
  Downloader/       app: status item, window, SwiftUI views (Downloads, History, Settings)
Tests/
  DownloaderCoreTests/  unit tests, plus opt-in live integration tests
Resources/bin/      bundled binaries (fetched or built, not committed), licenses/, README.md,
                    THIRD_PARTY_NOTICES.md
scripts/            fetch-binaries.sh, build-ffmpeg.sh, build-app.sh, make-dmg.sh, next-version.sh
design/             interface mock-up
docs/               README images
project.yml         XcodeGen spec
```

## Dependencies

The only Swift package is Sparkle, pinned to an exact version in `project.yml`. There is no vendored third-party source code.

### Swift packages

| Package | Version | Use | License | Open source |
|---|---|---|---|---|
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.10.1 | In-app updates (framework embedded in the app; `sign_update` in CI) | [MIT](https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE) | Yes |

Sparkle's license ships in the app at `Contents/Resources/bin/licenses/Sparkle-LICENSE`.

### Bundled programs

Copied into `Downloader.app/Contents/Resources/bin/` and run as separate processes. Versions are pinned in `scripts/fetch-binaries.sh` and `scripts/build-ffmpeg.sh`. License texts: `Resources/bin/licenses/`.

| Program | Version | License | Commercial use | Source |
|---|---|---|---|---|
| yt-dlp (`yt-dlp_macos`, official PyInstaller build, unmodified) | 2026.10.21 | yt-dlp itself is [Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE). Per the [yt-dlp README](https://github.com/yt-dlp/yt-dlp#release-files), the PyInstaller-bundled executables include GPLv3+ code, so the combined work is GPLv3+. The GPL part on macOS is mutagen (GPL-2.0-or-later) per [THIRD_PARTY_LICENSES.txt](https://github.com/yt-dlp/yt-dlp/blob/2026.10.21/THIRD_PARTY_LICENSES.txt) | Allowed | [github.com/yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp) |
| FFmpeg (`ffmpeg`, `ffprobe`), built by `scripts/build-ffmpeg.sh` | 9.0.2 | LGPL-2.1-or-later ([ffmpeg.org/legal.html](https://ffmpeg.org/legal.html)) | Allowed | [ffmpeg.org/releases](https://ffmpeg.org/releases/) |
| LAME, statically linked into `ffmpeg` and `ffprobe` | 4.0 | LGPL-2.0-or-later | Allowed | [lame.sourceforge.io](https://lame.sourceforge.io/) |
| Deno (official build, unmodified) | 2.9.8 | [MIT](https://github.com/denoland/deno/blob/main/LICENSE.md) | Allowed | [github.com/denoland/deno](https://github.com/denoland/deno) |

### License compliance

- **Source:** GPLv3 section 6(d) and LGPL-2.1 section 4 allow distributing binaries from a download place if the corresponding source is offered from the same place. Each release therefore attaches `build/sources/`: the yt-dlp source at the release tag (with its build scripts and the pinned, hash-checked macOS dependency list `bundle/requirements/macos.txt`), the FFmpeg and LAME source releases, and `build-ffmpeg.sh`. The source must correspond exactly to the binaries ([GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.html#AnonFTPAndSendSources)), so change versions only through the scripts.
- **License texts:** GPLv3 section 4 requires giving recipients a copy of the license. The texts are committed in `Resources/bin/licenses/` and copied into the app. Update them when a version changes.
- **Separate programs:** the app talks to these programs only through command-line arguments and pipes. The FSF considers such programs normally separate programs that may be distributed together as an aggregate, even under different licenses ([GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.html#MereAggregation)); it also notes that the final line is a legal question. On that basis the app's own code is MIT-licensed.
- **Commercial use:** GPL and LGPL permit selling and commercial distribution ([GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.html#DoesTheGPLAllowMoney)). FFmpeg is built without `--enable-nonfree`, so the build is redistributable.

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
