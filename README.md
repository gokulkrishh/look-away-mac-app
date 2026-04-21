# LookAway

[![Latest release](https://img.shields.io/github/v/release/gokulkrishh/look-away-mac-app?label=download)](https://github.com/gokulkrishh/look-away-mac-app/releases/latest)

A macOS menu-bar app that nudges you to rest your eyes every 20 minutes of
active screen use — the 20-20-20 rule, with Liquid Glass.

- Menu-bar only (no Dock icon)
- Measures **active** input time; pauses automatically when you walk away
- Full-screen break overlay on every display
- Skip or snooze 5 minutes
- Launch at login

## Download

### [**Download LookAway (latest .dmg)**](https://github.com/gokulkrishh/look-away-mac-app/releases/latest)

Requires **macOS 26 Tahoe or later**. Open the DMG, drag **LookAway.app** into **Applications**, and launch.

> **First launch — unsigned build:** macOS Gatekeeper blocks unsigned apps. Run this once in Terminal to bypass:
>
> ```sh
> xattr -cr /Applications/LookAway.app
> ```
>
> Or right-click **LookAway.app → Open**, then confirm in the dialog. Signed + notarized builds are planned.

## Requirements

- macOS 26 Tahoe or later (uses Liquid Glass)

### To build from source

- Xcode 26
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & run

```sh
xcodegen generate
open LookAway.xcodeproj
# then ⌘R in Xcode
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project LookAway.xcodeproj -scheme LookAway -configuration Debug build
open "$(xcodebuild -project LookAway.xcodeproj -scheme LookAway -configuration Debug -showBuildSettings | awk '/ BUILT_PRODUCTS_DIR / {print $3}')/LookAway.app"
```

## Smoke test (30 seconds)

1. In the menu bar, click the eye icon → **Settings…**
2. Set **Work interval** to `1 min`, **Break duration** to `5 sec`
3. Type or move the mouse for ~1 minute → the overlay appears
4. Click **Skip** or wait for the ring to complete
5. Walk away for 2+ minutes → the countdown pauses (check the menu bar)
6. Walk away for 5+ minutes → the accumulator resets to full

Restore the default `20 min / 20 sec` when done.

## Project layout

```
LookAway/
├── LookAwayApp.swift        @main, MenuBarExtra + Settings scenes
├── AppState.swift           Observable state, wires scheduler ↔ overlay
├── BreakScheduler.swift     Active/idle loop, emits break events
├── IdleMonitor.swift        IOKit HIDIdleTime wrapper
├── OverlayController.swift  One NSWindow per display at shielding level
├── Views/
│   ├── MenuBarContent.swift
│   ├── BreakOverlayView.swift
│   └── SettingsView.swift
└── Services/
    └── LaunchAtLogin.swift  SMAppService.mainApp wrapper
```

## License

MIT. See [LICENSE](LICENSE).
