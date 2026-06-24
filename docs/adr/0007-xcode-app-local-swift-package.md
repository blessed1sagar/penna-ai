# Xcode app target, with logic kept in a local Swift package

v1 is built as an **Xcode macOS App** project. The existing `OllamaKit` (and future logic — prompt building, clipboard service, etc.) stays as a **local Swift package** that the app depends on, so logic remains unit-testable from the terminal (`swift test`) while the app itself is a thin SwiftUI menu-bar shell.

We chose this over a pure SwiftPM executable because SwiftPM does not cleanly produce a Dock-less menu-bar `.app` bundle: the `LSUIElement` flag, `Info.plist`, app icon, and code signing all need bundle machinery that Xcode provides out of the box and SwiftPM does not (it would require third-party packaging tools and manual `Info.plist` workarounds). This keeps `ADR-0002`'s native Swift/SwiftUI choice and just commits to the conventional way of shipping it.

## Status

accepted

## Consequences

- The repo contains **both** a `Package.swift` (the `OllamaKit` library + its tests) **and** an `.xcodeproj` (the app). This is intentional, not a mistake.
- Build/run the **app** from Xcode; run the **library tests** with `swift test` from the terminal. Both keep working independently.
- New non-UI logic should be added to the Swift package (testable), not the app target, wherever practical.
