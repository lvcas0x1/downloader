# Proposal

## Why

Users need a lightweight, native macOS way to download media from any site
supported by yt-dlp (plus plain HTTPS links) by pasting a URL, without using
the command line. Existing CLI usage requires memorizing flags and offers no
preview, queue, progress visibility, or history. This change introduces a
minimal menubar-only app that wraps a bundled yt-dlp/ffmpeg, previews what a
URL resolves to before downloading, and manages the download lifecycle and
history.

## What Changes

- A menubar-only macOS app (no Dock icon, `LSUIElement`) whose status-bar icon
  toggles a single compact window.
- Paste a URL (or read the clipboard) and resolve a **preview** of what will be
  downloaded before any bytes are written: single item shows title/uploader/
  duration/thumbnail/format; a playlist or watchlist (e.g. YouTube playlist,
  Bilibili collection) lists every entry with per-entry selection.
- Download engine using a **bundled** yt-dlp and ffmpeg: real-time progress and
  speed, Start / Pause / Stop controls, and **parallel** downloads with a
  user-configurable concurrency limit. Stop cancels and deletes the in-progress
  (partial) file(s); Pause keeps partial files for resume.
- Settings: destination folder (default: user Downloads), download rate limit
  (default: unlimited), concurrency limit, history retention count (0–1000),
  and the browser used for `--cookies-from-browser`.
- Browser-cookie support (`--cookies-from-browser`) so login-required/private
  content can be downloaded using the user's existing browser session.
- A **History** tab: every completed (or failed) download is recorded, with a
  bulk "Clear all" action and a per-row right-click **re-download**. Retention
  is capped by the configurable count (0 disables history; max 1000).

## Capabilities

### New Capabilities
- `menubar-app`: Menubar-only presence and lifecycle — no Dock icon, status-bar
  item, click-to-toggle window, and the two-tab (Downloads / History) shell.
- `download-intake`: URL input, resolution, and pre-download preview, including
  playlist/collection expansion and per-entry selection.
- `download-engine`: The download lifecycle — queue, parallel execution,
  Start/Pause/Stop/resume, progress and speed reporting, rate limiting, and the
  bundled yt-dlp/ffmpeg integration.
- `download-history`: Recording, listing, bulk clearing, and re-downloading of
  past downloads, bounded by a retention count.
- `app-settings`: Persisted user preferences — destination folder, rate limit,
  concurrency, retention count, and cookie-source browser.

### Modified Capabilities
<!-- None. Greenfield app; no existing specs under openspec/specs/. -->

## Impact

- **New application**: native macOS app (SwiftUI + AppKit status item),
  minimum target macOS 14 (Sonoma). Apple silicon + Intel.
- **Bundled dependencies**: yt-dlp and ffmpeg binaries shipped inside the
  `.app`; requires code signing + notarization accommodation for the bundled
  executables and an update path for them.
- **Local persistence**: settings and history stored locally (no network
  service).
- **External process**: the app spawns and manages yt-dlp subprocesses and
  parses their JSON/progress output.
- Out of scope (v1): manual login forms, format/codec transcoding beyond
  yt-dlp defaults, scheduled downloads, BitTorrent/magnet links.
