# download-engine

## Purpose

Define the download lifecycle: queuing, parallel execution, Start/Pause/Stop/
resume controls, live progress and speed reporting, rate limiting, and the use
of a bundled yt-dlp and ffmpeg to perform transfers.

## ADDED Requirements

### Requirement: Bundled Download Binaries

The app SHALL perform all downloads using yt-dlp, ffmpeg, ffprobe, and Deno
binaries bundled inside the application. It MUST NOT depend on a
system-installed copy of any of them. Deno is the JavaScript runtime yt-dlp
needs to solve YouTube challenges (yt-dlp wiki: EJS).

#### Scenario: Use bundled binaries

- **WHEN** a resolution or download starts
- **THEN** the app invokes the yt-dlp binary shipped inside the app bundle
- **AND** points yt-dlp at the bundled ffmpeg/ffprobe for any merge/post-processing step
- **AND** passes the bundled Deno as the JavaScript runtime (`--js-runtimes deno:<path>`)

#### Scenario: Missing or unusable binary

- **WHEN** a bundled binary is missing or cannot be executed
- **THEN** the app surfaces an actionable error instead of silently failing
- **AND** the affected download is marked failed

### Requirement: Download Queue with Configurable Parallelism

Confirmed downloads SHALL enter a queue and run in parallel up to a
user-configured concurrency limit; items beyond the limit SHALL wait as queued.

#### Scenario: Run within the limit

- **WHEN** the number of active downloads is below the concurrency limit and queued items exist
- **THEN** the app starts queued items until the limit is reached

#### Scenario: Queue beyond the limit

- **WHEN** more items are confirmed than the concurrency limit allows
- **THEN** the excess items are shown as queued and start only as active slots free up

#### Scenario: Collection enqueues each entry

- **WHEN** a multi-entry collection is confirmed for download
- **THEN** each selected entry becomes its own queue item

### Requirement: Live Progress and Speed

For each active download the app SHALL display live progress (percent and/or
downloaded/total size) and the current download speed.

#### Scenario: Progress updates

- **WHEN** a download is transferring data
- **THEN** its progress percentage and current speed update continuously in the Downloads tab

#### Scenario: Indeterminate total

- **WHEN** the total size is unknown
- **THEN** the app shows downloaded bytes and speed without a percentage

### Requirement: Start, Pause, and Resume

Each download SHALL be individually controllable with Start, Pause, and resume.
Pausing SHALL retain the partial file so the download can resume from where it
stopped. A row's buttons SHALL follow its state: ready or failed shows Download
and Audio; queued or running shows Pause and Stop; paused shows Resume and Stop.

#### Scenario: Start swaps to Pause and Stop

- **WHEN** the user presses Download or Audio on a ready row
- **THEN** the download starts in that mode
- **AND** the row's buttons change to Pause and Stop

#### Scenario: Pause swaps to Resume

- **WHEN** the user presses Pause
- **THEN** the Pause button changes to Resume

#### Scenario: Pause a download

- **WHEN** the user pauses an active download
- **THEN** the transfer stops
- **AND** the partially downloaded file is retained

#### Scenario: Resume a paused download

- **WHEN** the user resumes a paused download
- **THEN** the transfer continues from the retained partial file rather than restarting from zero

### Requirement: Stop Deletes Partial Files

Stopping a download SHALL cancel it, delete any in-progress/partial file(s) for
that download (including temporary fragment files), and remove its row from the
Downloads list. Each download keeps its intermediary files in its own temporary
directory (yt-dlp `--paths temp:`), so stopping one download SHALL NOT affect the
partial files of parallel downloads.

#### Scenario: Stop an active download

- **WHEN** the user stops an active download
- **THEN** the transfer is cancelled
- **AND** the partial output file and any temporary fragment files for it are deleted from disk
- **AND** the row is removed from the Downloads list

#### Scenario: Stop a paused download

- **WHEN** the user stops a paused download
- **THEN** its retained partial file is deleted and its row is removed

#### Scenario: Parallel downloads are isolated

- **WHEN** two downloads run in parallel and the user stops one
- **THEN** only the stopped download's partial files are deleted

### Requirement: Audio-Only Download

The app SHALL offer an audio-only mode that downloads the media and converts it
to MP3 at 256 kbps (yt-dlp `--extract-audio --audio-format mp3 --audio-quality
256K`, which requires the bundled ffmpeg and ffprobe). Audio-only rows SHALL use
the same Pause/Resume/Stop controls as video downloads.

#### Scenario: Download audio only

- **WHEN** the user presses Audio on a ready row
- **THEN** the result is an MP3 file at 256 kbps in the destination folder
- **AND** the row and its history record are labeled as audio

### Requirement: Rate Limiting

The app SHALL apply a user-configured maximum download rate to transfers. When
the limit is set to unlimited, no rate cap SHALL be applied.

#### Scenario: Apply a rate cap

- **WHEN** a rate limit is configured and a download runs
- **THEN** the transfer is capped at approximately the configured rate

#### Scenario: Unlimited rate

- **WHEN** the rate limit is set to unlimited
- **THEN** downloads run without an imposed rate cap

### Requirement: Destination Folder

Completed files SHALL be written to the user-configured destination folder.

#### Scenario: Write to destination

- **WHEN** a download completes
- **THEN** the finished file is located in the configured destination folder

### Requirement: Completion and Failure Outcomes

Each download SHALL end in a terminal outcome of completed or failed. Both
outcomes SHALL move the item from the Downloads list to History.

#### Scenario: Successful completion

- **WHEN** a download finishes successfully
- **THEN** it is marked completed
- **AND** a history record is created for it
- **AND** it is removed from the Downloads list automatically

#### Scenario: Failure

- **WHEN** a download fails (network, extractor, or post-processing error)
- **THEN** it is marked failed with a reason
- **AND** a history record is created for it, showing the reason
- **AND** it is removed from the Downloads list automatically
