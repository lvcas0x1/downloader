# download-history

## Purpose

Define how finished downloads are recorded, listed in the History tab, bulk
cleared, and re-downloaded, with a user-configurable retention bound.

## ADDED Requirements

### Requirement: History Records

Every download that reaches a terminal outcome (completed or failed) SHALL
produce a history record retaining the source URL, title, outcome, destination
path, timestamp, mode (video or audio), and, for failures, the reason.

#### Scenario: Record on completion

- **WHEN** a download completes or fails
- **THEN** a history record is created capturing the source URL, title, outcome, destination path, and timestamp
- **AND** a failed record shows its failure reason in the History row

#### Scenario: History survives relaunch

- **WHEN** the app is quit and relaunched
- **THEN** previously recorded history is still present (subject to the retention bound)

### Requirement: History Listing

The History tab SHALL list recorded downloads, most recent first, showing each
record's title, outcome, and timestamp.

#### Scenario: View history

- **WHEN** the user opens the History tab
- **THEN** recorded downloads are listed newest-first with title, outcome, and timestamp

### Requirement: Bulk Clear

The History tab SHALL provide a single action to clear all history records. The
action SHALL require confirmation before deleting.

#### Scenario: Clear all with confirmation

- **WHEN** the user triggers "Clear all" and confirms
- **THEN** all history records are removed
- **AND** the history list becomes empty

#### Scenario: Cancel clear

- **WHEN** the user triggers "Clear all" and cancels the confirmation
- **THEN** no records are removed

### Requirement: Re-Download from History

Each history row SHALL show, at its right, a Download (video) button, an Audio
button, and a delete button. Re-downloading SHALL move the record from History
to the Downloads list and start the download immediately in the chosen mode.
Records store the entry's own URL, so re-downloading a playlist entry fetches
only that entry.

#### Scenario: Re-download a record

- **WHEN** the user presses Download or Audio on a history row
- **THEN** the record is removed from History
- **AND** a row for it appears in the Downloads list and starts automatically in that mode

#### Scenario: Re-download a failed record

- **WHEN** the user presses Download or Audio on a failed history row
- **THEN** it moves to the Downloads list and starts again as a new download attempt

### Requirement: Delete a History Record

Each history row SHALL offer a delete action that removes only that record. The
downloaded file SHALL NOT be deleted.

#### Scenario: Delete one record

- **WHEN** the user presses delete on a history row
- **THEN** only that record is removed from History
- **AND** the downloaded file remains on disk

### Requirement: Retention Bound

History retention SHALL be bounded by a configurable count from 0 to 1000. When
the count of records would exceed the bound, the oldest records SHALL be
discarded. A bound of 0 SHALL disable history.

#### Scenario: Trim oldest beyond bound

- **WHEN** the number of records exceeds the configured retention count
- **THEN** the oldest records are discarded so the total does not exceed the bound

#### Scenario: Retention disabled

- **WHEN** the retention count is set to 0
- **THEN** no history records are kept
- **AND** the History tab shows an empty list

#### Scenario: Lowering the bound trims immediately

- **WHEN** the user lowers the retention count below the current number of records
- **THEN** the oldest records are discarded immediately to fit the new bound
