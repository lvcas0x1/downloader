# Tasks

## 1. Project Setup and Bundled Binaries

- [x] 1.1 Create the Xcode app project (SwiftUI, min target macOS 14, universal) and verify it builds and runs
- [x] 1.2 Set `LSUIElement=true` in Info.plist and verify at launch there is no Dock icon and no Cmd-Tab entry
- [x] 1.3 Add pinned `yt-dlp` and `ffmpeg` binaries to the bundle (Resources/helper) and verify each runs from its absolute bundle path (`yt-dlp --version`, `ffmpeg -version`) via a smoke test
- [ ] 1.4 Configure Developer ID signing (non-sandboxed), hardened runtime, and a notarization step covering the bundled binaries; verify a signed+notarized build launches on a clean machine without Gatekeeper blocking

## 2. Menubar Shell (capability: menubar-app)

- [x] 2.1 Add an `NSStatusItem` and borderless window; verify clicking the icon toggles the window (open+focus when hidden, hide when frontmost)
- [x] 2.2 Add a status-item context menu with Quit; verify Quit terminates the app and triggers stop/cleanup of active downloads
- [x] 2.3 Build the two-tab shell (Downloads default, History); verify tab switching and that no window opens automatically on launch
- [ ] 2.4 Add UI tests covering no-auto-window, toggle behavior, and default tab

## 3. Settings Store (capability: app-settings)

- [x] 3.1 Implement persisted settings (destination, rate limit, concurrency, retention 0–1000, cookie-source browser) in `UserDefaults`; verify values survive relaunch
- [x] 3.2 Default destination to the user's Downloads folder via a security-scoped bookmark; verify first-run default and that a user-chosen folder persists and is writable
- [x] 3.3 Validate inputs (rate default unlimited, concurrency ≥ 1, retention clamped to 0–1000); verify unit tests for defaults and out-of-range rejection/clamping
- [x] 3.4 Build the Settings UI; verify each control reads/writes the store

## 4. yt-dlp Process Layer

- [x] 4.1 Implement a process runner that launches the bundled yt-dlp with `--ffmpeg-location` and streams stdout/stderr off the main thread; verify a basic download writes a file to the destination
- [x] 4.2 Implement the preview resolver: `--dump-single-json --flat-playlist` for collections and `--dump-json -s` for single items; verify parsed title/uploader/duration/entries against known URLs
- [x] 4.3 Implement the `--newline --progress-template` parser for downloaded/total bytes, speed, and ETA; verify the parser against captured sample output (including non-progress lines)
- [x] 4.4 Apply `--limit-rate` when set and `--cookies-from-browser` when a browser source is selected; verify a rate-capped run is throttled and a cookie run passes the flag (unit-test command construction)

## 5. URL Intake and Preview (capability: download-intake)

- [x] 5.1 Build the URL input field (no clipboard button); verify non-http input shows an inline error and no resolution starts
- [x] 5.2 Show a single-item preview (title, source, duration, thumbnail, target format) with a Start control; verify against a single-video URL
- [x] 5.3 Add every collection entry as its own ready row with ready count and Download all / Audio all; verify only started rows download
- [x] 5.4 Show resolving indicator with cancel, and a failure state with reason; verify no bytes are written before confirmation
- [ ] 5.5 Verify a plain HTTPS file link previews filename/size and can be started

## 6. Download Lifecycle and Queue (capability: download-engine)

- [x] 6.1 Implement the queue/scheduler honoring the concurrency limit; verify items beyond the limit stay queued and start as slots free, and that each collection entry becomes its own item
- [x] 6.2 Render live progress (percent and/or bytes) and speed per active download, including an indeterminate-total case; verify values update continuously
- [x] 6.3 Implement Pause (terminate, retain partial) and Resume (relaunch with `-c/--continue`); verify resume continues rather than restarting from zero
- [x] 6.4 Implement Stop: terminate and delete the partial output plus `*.part`/`*.ytdl`/fragment temp files (for active and paused items); verify no partial files remain on disk after stop
- [x] 6.5 Surface bundled-binary-missing/unusable errors and mark the download failed; verify by pointing at an unusable binary path in a test
- [x] 6.6 Map terminal outcomes (completed/failed with reason) and emit a history record; verify both outcomes create records

## 7. History (capability: download-history)

- [x] 7.1 Implement the local history store with records (URL, title, outcome, destination path, timestamp); verify records persist across relaunch
- [x] 7.2 Build the History list (newest-first: title, outcome, timestamp); verify ordering and fields
- [x] 7.3 Implement "Clear all" with a confirmation dialog; verify confirm empties history and cancel leaves it unchanged
- [x] 7.4 Implement per-row Download / Audio re-download (moves the record to Downloads and auto-starts) and per-row delete (record only); verify a re-download starts a new attempt
- [x] 7.5 Enforce the retention bound on insert and on retention-count change, discarding oldest; verify 0 keeps nothing and lowering the bound trims immediately

## 8. Integration Verification

- [ ] 8.1 End-to-end: paste a playlist URL, preview, deselect some entries, download in parallel, pause/resume one, stop another (confirm its partial file is deleted), and confirm completed items appear in History with correct retention
- [ ] 8.2 End-to-end: re-download a history record and confirm it runs to completion and writes to the configured destination

## 9. Row-Based Downloads and Audio-Only Mode

- [x] 9.1 Replace the separate preview screen with ready rows that accumulate in the Downloads list across resolutions; verify active downloads stay visible while another URL resolves
- [x] 9.2 Swap row controls by state (ready/failed: Download, Audio; queued/running: Pause, Stop; paused: Resume, Stop); verify on the live app
- [x] 9.3 Stop removes the row and deletes only that item's partial files via a per-item `--paths temp:` directory; verify a parallel download's partial survives (unit test) and the stopped item's temp directory is gone (live app)
- [x] 9.4 Add audio-only mode (`--extract-audio --audio-format mp3 --audio-quality 256K`) and bundle ffprobe (required by `-x`); verify the output is MP3 at 256 kbps (`afinfo`)
- [x] 9.5 Fix duplicate resolution on Return (field onCommit + default-action button); verify one row per submission on the live app
