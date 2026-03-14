# Trackpad Commander

Trackpad Commander is a macOS menu bar app that maps trackpad gestures to local actions such as shell commands, app launches, file opens, URLs, AppleScript, and synthetic middle click.

The project is built with SwiftUI, stores configuration in JSON under Application Support, and captures global trackpad input through Apple's private `MultitouchSupport.framework`.

## Features

- Menu bar app with a dedicated Settings window.
- Bind gestures to actions and enable, disable, duplicate, test, edit, or delete each binding.
- Supported gestures:
  - Two-finger tap
  - Three-finger tap
  - Four-finger tap
  - Three-finger swipes in all directions
  - Four-finger swipes in all directions
  - Two-finger pinch in and pinch out
- Supported actions:
  - Shell command
  - Open app by bundle identifier or path
  - Open file or folder
  - Open URL
  - AppleScript
  - Synthetic middle click
- Automatic conflict handling for macOS trackpad settings that would otherwise consume supported gestures.
- Local logging with export support.
- Launch-at-login toggle.
- Adjustable three-finger tap sensitivity and optional gesture diagnostics.

## Requirements

- macOS 14.0 or later
- A recent Xcode release with Swift 6 support

Notes:

- Global gesture capture depends on `/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport`.
- Synthetic middle click requires Accessibility access.
- AppleScript actions may trigger Automation permission prompts from macOS.
- Because the app uses a private framework, it is not suitable for Mac App Store distribution.

## Project Layout

`TrackpadCommander/`

- `App/`: app entry point and shared state orchestration
- `Domain/`: gestures, bindings, action specs, and config models
- `GestureCapture/`: multitouch bridge and raw touch frame types
- `GestureRecognition/`: gesture classifier and thresholds
- `Execution/`: action execution and result handling
- `Persistence/`: config and log storage
- `Conflicts/`: trackpad preference override and restore logic
- `UI/`: menu bar and settings views

`TrackpadCommanderTests/`

- Unit tests for gesture recognition, fallback logic, persistence, conflict rules, and shell execution

`Tools/`

- Swift scripts for generating and installing the app icon assets

## Configuration and Logs

Trackpad Commander stores files in:

- `~/Library/Application Support/TrackpadCommander/config.json`
- `~/Library/Application Support/TrackpadCommander/logs/recent-log.json`

The app creates a default configuration on first launch with one binding:

- Three-finger tap -> middle click

## Conflict Handling

When you enable bindings for gestures that overlap with built-in macOS trackpad behaviors, the app attempts to disable the relevant preference keys in these domains:

- `com.apple.AppleMultitouchTrackpad`
- `com.apple.driver.AppleBluetoothMultitouch.trackpad`

The original values are stored and can be restored from the app.

## Testing

The test target covers:

- Tap, swipe, and pinch recognition
- Three-finger tap fallback behavior
- Config persistence and default backfill
- Conflict rule selection
- Shell action success and timeout behavior

Run tests from Xcode with the `TrackpadCommanderTests` target.

## Limitations

- Gesture capture is unavailable if the private multitouch framework cannot be loaded.
- Recognition quality depends on device behavior and current threshold tuning.
- Some trackpad preference overrides may still require manual verification after macOS updates.
- Middle click injection may behave differently across apps and OS versions.
