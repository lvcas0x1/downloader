# app-settings

## Purpose

Define the user-configurable, persisted preferences that govern downloads:
destination folder, rate limit, concurrency, history retention, and the browser
used as the cookie source.

## ADDED Requirements

### Requirement: Destination Folder Setting

The app SHALL let the user choose the download destination folder and SHALL
default it to the user's Downloads folder. The chosen folder SHALL persist
across launches.

#### Scenario: Default destination

- **WHEN** the app runs for the first time with no configured destination
- **THEN** the destination defaults to the user's Downloads folder

#### Scenario: Change destination

- **WHEN** the user selects a different destination folder
- **THEN** subsequent downloads are written there
- **AND** the choice persists after relaunch

### Requirement: Rate Limit Setting

The app SHALL let the user set a maximum download rate and SHALL default it to
unlimited.

#### Scenario: Default unlimited

- **WHEN** the app runs with no configured rate limit
- **THEN** the rate limit is unlimited

#### Scenario: Set a rate limit

- **WHEN** the user sets a rate limit value
- **THEN** the value persists and is applied to subsequent downloads by the download-engine

### Requirement: Concurrency Setting

The app SHALL let the user set the maximum number of parallel downloads, with a
value of at least 1.

#### Scenario: Default concurrency

- **WHEN** the app runs with no configured concurrency
- **THEN** a default concurrency of at least 1 is used

#### Scenario: Change concurrency

- **WHEN** the user changes the concurrency limit
- **THEN** the download-engine honors the new limit for scheduling queued downloads

### Requirement: History Retention Setting

The app SHALL let the user set the history retention count within the range 0 to
1000 and SHALL reject values outside that range.

#### Scenario: Accept valid retention

- **WHEN** the user sets a retention count between 0 and 1000 inclusive
- **THEN** the value persists and bounds history per the download-history capability

#### Scenario: Reject out-of-range retention

- **WHEN** the user enters a retention count below 0 or above 1000
- **THEN** the value is rejected or clamped to the valid range

### Requirement: Cookie Source Setting

The app SHALL let the user select a browser whose cookies are used for
login-required content, and SHALL allow a "none" option that disables cookie
use.

#### Scenario: Select a browser for cookies

- **WHEN** the user selects a supported browser as the cookie source
- **THEN** downloads use that browser's cookies (via `--cookies-from-browser`) for authenticated content

#### Scenario: No cookie source

- **WHEN** the cookie source is set to none
- **THEN** downloads are attempted without browser cookies
