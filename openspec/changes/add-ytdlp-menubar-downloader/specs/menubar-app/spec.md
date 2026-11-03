# menubar-app

## Purpose

Define the app's menubar-only presence and window shell: it runs without a Dock
icon, lives as a macOS status-bar item, and toggles a single compact window with
Downloads and History tabs.

## ADDED Requirements

### Requirement: No Dock Presence

The app SHALL run as a menubar-only agent. It MUST NOT show a Dock icon and MUST
NOT appear in the Cmd-Tab application switcher.

#### Scenario: App launches as agent

- **WHEN** the app is launched
- **THEN** no Dock icon appears
- **AND** the app does not appear in the Cmd-Tab switcher
- **AND** a status-bar item appears in the system menubar

#### Scenario: No windows open on launch

- **WHEN** the app finishes launching
- **THEN** no window is shown automatically
- **AND** only the menubar status item is visible

### Requirement: Status-Bar Item Toggles the Window

Clicking the menubar status item SHALL toggle the app's main window: open and
focus it when hidden, hide it when already frontmost.

#### Scenario: Open window from menubar

- **WHEN** the user clicks the menubar icon and the window is not visible
- **THEN** the main window opens and becomes key/frontmost

#### Scenario: Hide window from menubar

- **WHEN** the user clicks the menubar icon while the window is visible and frontmost
- **THEN** the window hides

#### Scenario: Dismiss by clicking elsewhere

- **WHEN** the window is open and the user clicks outside it
- **THEN** the window stays open until explicitly dismissed via the menubar icon or its close control

### Requirement: Quit Control

The app SHALL provide a way to quit from the menubar context (e.g. right-click
or an in-window control), since there is no Dock menu.

#### Scenario: Quit the app

- **WHEN** the user selects Quit from the menubar item's menu
- **THEN** the app terminates
- **AND** any in-progress downloads are stopped and their partial files deleted per the download-engine stop behavior

### Requirement: Two-Tab Window Shell

The main window SHALL present exactly two tabs: "Downloads" (active and queued
transfers plus URL intake) and "History" (completed and failed records). The
window SHALL follow `design/interface.png`: a unified frame where the title bar
and content share one surface, the tab switcher centered in the title bar row
(selected tab filled with the accent color), and the Settings button at the
trailing edge of the title bar row.

#### Scenario: Switch between tabs

- **WHEN** the user selects the History tab
- **THEN** the history list is shown
- **AND** selecting the Downloads tab returns to the active/queued transfer view

#### Scenario: Default tab on open

- **WHEN** the window opens
- **THEN** the Downloads tab is shown by default
