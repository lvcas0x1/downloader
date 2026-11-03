# download-intake

## Purpose

Define how the user supplies a URL and how the app resolves and previews what
that URL will download — including expanding playlists and collections — before
any download begins.

## ADDED Requirements

### Requirement: URL Input

The app SHALL accept a URL via a paste field in the Downloads tab. No separate
clipboard button is shown.

#### Scenario: Paste a URL

- **WHEN** the user pastes a URL into the input field and confirms
- **THEN** the app begins resolving a preview for that URL

#### Scenario: Reject non-HTTP input

- **WHEN** the user submits text that is not an http:// or https:// URL
- **THEN** the app shows an inline validation error
- **AND** no resolution is attempted

### Requirement: Preview Before Download

Submitting a URL SHALL first resolve it and add each resolved entry to the
Downloads list as a ready row, and no bytes SHALL be written to the destination
until the user presses Download or Audio on that row. Resolved rows SHALL
accumulate: resolving another URL appends rows and leaves existing rows
(including active downloads) visible.

#### Scenario: Single item preview

- **WHEN** a URL resolves to a single media item
- **THEN** a row is added showing its title and duration/uploader (or source host)
- **AND** the row shows Download and Audio buttons beside it, plus a remove control
- **AND** the URL field clears for the next URL

#### Scenario: Rows accumulate

- **WHEN** the user resolves a second URL while the first item is downloading
- **THEN** the first item's row stays visible with its progress and controls
- **AND** the new entry is appended as a ready row

#### Scenario: One submission per confirm

- **WHEN** the user presses Return in the URL field
- **THEN** exactly one resolution runs and each entry is added once

#### Scenario: Resolution in progress

- **WHEN** the app is resolving a URL
- **THEN** a resolving indicator is shown in the input bar
- **AND** the user can cancel the resolution

#### Scenario: Resolution failure

- **WHEN** resolution fails (unsupported site, network error, or unavailable content)
- **THEN** the app shows the failure reason inline below the input bar
- **AND** no download starts and existing rows stay visible

### Requirement: Playlist and Collection Expansion

When a URL resolves to a playlist, watchlist, channel, or collection (e.g. a
YouTube playlist or Bilibili collection), every entry in the collection SHALL be
added as its own ready row.

#### Scenario: Playlist entries listed

- **WHEN** a URL resolves to a collection of multiple entries
- **THEN** each entry is added as a ready row with its title and (when available) duration
- **AND** the ready count is shown with "Download all" and "Audio all" bulk actions

#### Scenario: Choose a subset

- **WHEN** the user starts some rows and removes others
- **THEN** only the started rows download

#### Scenario: Video URL that also names a playlist

- **WHEN** a URL refers to both a single video and a regular playlist (e.g. `watch?v=…&list=PL…`)
- **THEN** the whole playlist is resolved and every entry is added as a ready row (yt-dlp `--yes-playlist`)

#### Scenario: Video URL inside a YouTube Mix

- **WHEN** a URL refers to a video inside an auto-generated YouTube Mix (`list=RD…`)
- **THEN** only that video is resolved (yt-dlp `--no-playlist`), since a Mix is effectively endless

### Requirement: Plain HTTPS Link Support

The app SHALL support direct HTTPS links to files that yt-dlp's generic handling
can download, in addition to extractor-supported sites.

#### Scenario: Direct file link

- **WHEN** the user submits a plain HTTPS link to a downloadable file
- **THEN** a ready row shows the resolved filename and source host
- **AND** the user can start the download
