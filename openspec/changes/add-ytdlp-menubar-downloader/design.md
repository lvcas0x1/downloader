# Design

## Context

Greenfield native macOS app. See proposal.md - Why for motivation. Downloads are
performed by shelling out to a bundled `yt-dlp` and `ffmpeg`; the app is a UI and
process-orchestration layer over them. Confirmed product decisions: binaries are
bundled inside the `.app`; downloads run in parallel with a configurable limit;
login-required content is handled via browser cookies; the app ships via
**Developer ID direct distribution** (not the Mac App Store).

Verified yt-dlp interface (official README, master):
- `-j, --dump-json` / `-J, --dump-single-json`: print JSON info, no download — used for preview.
- `--flat-playlist`: list a playlist's entries cheaply, without resolving each — used for collection preview.
- `-I, --playlist-items`: restrict to selected entries — used for per-entry selection.
- `-s, --simulate` / `--skip-download`: resolve without writing — used for preview.
- `--progress-template [TYPES:]TEMPLATE`, `--newline`, `--progress-delta SECONDS`: machine-readable progress/speed.
- `--limit-rate RATE` (`-r`): rate cap (e.g. `4.2M`); omit for unlimited.
- `-c, --continue` / `--no-continue`: resume partial files (default on) — used for pause/resume.
- `-P, --paths` and `-o, --output`: destination directory and filename template.
- `--ffmpeg-location PATH`: point at the bundled ffmpeg.
- `--cookies-from-browser BROWSER`: use a browser's cookies for authenticated content.

Source: <https://github.com/yt-dlp/yt-dlp> README (General/Download/Verbosity/Filesystem/Authentication option sections).

## Goals / Non-Goals

**Goals:**
- Thin, native SwiftUI + AppKit menubar app orchestrating bundled CLIs.
- Deterministic lifecycle control (start/pause/stop/resume) mapped onto yt-dlp process signals and `--continue`.
- Robust parsing of yt-dlp progress for live percent/speed.
- Local-only persistence (settings + history); no network service, no telemetry.

**Non-Goals:**
- Reimplementing any extractor logic in Swift; yt-dlp owns site support.
- A custom HTTP downloader; yt-dlp (incl. its generic handler) covers plain HTTPS.
- Auto-updating the bundled binaries in v1 (ship a known-good pinned pair; update path noted as a risk).

## Decisions

- **Menubar-only via `LSUIElement`**: set `LSUIElement=true` in Info.plist so no Dock icon and no app-switcher entry; an `NSStatusItem` owns the toggle. Alternative (`MenuBarExtra`, macOS 13+) is simpler but gives less control over click-to-toggle a full window; use `NSStatusItem` + a borderless/panel window for precise toggle behavior.
- **UI stack**: SwiftUI views hosted from an AppKit `NSApplicationDelegate` (for the status item and window management). Pure SwiftUI `MenuBarExtra` is the fallback if AppKit glue proves unnecessary.
- **Process orchestration**: each download is one `Process` running the bundled yt-dlp. Preview is a separate short-lived `Process` with `--dump-single-json --flat-playlist` (collections) or `--dump-json -s` (single). Rationale: one-process-per-download gives clean per-item pause/stop and isolates failures.
- **Progress parsing**: pass `--newline --progress-template` with a delimited template emitting downloaded/total bytes, speed, and ETA; read stdout line-by-line off the main thread and publish to the UI. Avoids scraping the human-readable progress bar.
- **Pause/resume**: pause = terminate the process (SIGTERM) while leaving `.part`/fragment files; resume = relaunch the same yt-dlp command relying on default `-c/--continue`. yt-dlp stores the page URL and pins the chosen format, so resume re-resolves safely. Alternative (SIGSTOP/SIGCONT) holds the socket open and is fragile across network changes — rejected.
- **Stop semantics**: stop = terminate the process, then delete the destination partial file and any `*.part`, `*.ytdl`, and fragment temp files for that item. Use a dedicated per-download temp/output path so cleanup is unambiguous.
- **Parallelism**: an in-app scheduler caps concurrently running processes at the configured limit; excess items stay queued. This is independent of yt-dlp's own `-N` fragment concurrency.
- **Distribution**: Developer ID + hardened runtime + notarization, distributed directly (not the Mac App Store). Rationale: the Store forbids bundling/executing an external interpreter-based binary like yt-dlp. Developer ID also permits running **non-sandboxed**, which keeps spawning bundled executables and writing to the user's chosen folder straightforward.
- **Destination & naming**: pass `-P <dir>` and a stable `-o` template. Because the app runs non-sandboxed, a plain folder path suffices; adopt security-scoped bookmarks only if the App Sandbox is enabled later.
- **Cookies**: pass `--cookies-from-browser <browser>` only when a source other than "none" is selected.
- **Persistence**: settings in `UserDefaults`; history in a small local store (JSON file or SQLite via a lightweight layer). History trimming enforced on every insert and on retention-count change.
- **Bundled binaries**: ship `yt-dlp` and `ffmpeg` under `Contents/Resources` (or a helper), reference by absolute bundle path, and point yt-dlp at ffmpeg with `--ffmpeg-location`. They must be signed and covered by the app's notarization.

## Risks / Trade-offs

- **Bundled-binary staleness** → yt-dlp needs frequent updates as sites change; a pinned binary will rot. Mitigation: pin a recent known-good build for v1, isolate the binary path behind one component, and plan an update mechanism as a follow-up change.
- **Code signing / notarization of bundled executables** → hardened runtime and notarization must cover yt-dlp (a Python-based binary) and ffmpeg, or launch is blocked. Mitigation: validate signing/notarization early; may require entitlements or a packaged standalone yt-dlp.
- **Progress-template format drift / non-progress output** → parsing can break on warnings or post-processing lines. Mitigation: strict template, tolerant parser, treat unparsable lines as no-ops.
- **Pause-as-terminate loses in-flight buffer** → resume restarts the current fragment, not mid-byte. Mitigation: acceptable; `--continue` resumes at fragment/file boundaries.
- **Browser-cookie extraction may require keychain/disk access** → some browsers lock their cookie DB or need decryption permission. Mitigation: surface a clear error and fall back to no-cookie attempt.
- **Developer ID distribution is outside the Mac App Store** → no Store review/reach, and users must allow a non-Store app on first launch. Mitigation: accepted trade-off; required because the Store forbids bundling/executing yt-dlp. Ship signed + notarized so Gatekeeper allows launch normally.
