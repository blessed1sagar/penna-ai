//
//  OpenShortcutSettingsTests.swift
//  OllamaKitTests
//
//  Issue #15 — rebinding the Open shortcut from a Settings screen.
//

import Testing
import KeyboardShortcuts
@testable import OllamaKit

@MainActor
@Suite struct OpenShortcutSettingsTests {
    // The rebinding contract: the Settings Recorder binds `.openPanel`, the live
    // hotkey handler (issue #14) is registered on `.openPanel`, and persistence is
    // keyed on `.openPanel`. One name, one source of truth — so a rebind takes
    // effect immediately and survives a restart. This asserts that a shortcut set
    // on `.openPanel` is exactly what we read back from it. We save and restore the
    // existing binding so the test never clobbers a real user shortcut.
    @Test func shortcutSetForOpenPanelRoundTrips() {
        let saved = KeyboardShortcuts.getShortcut(for: .openPanel)
        defer { KeyboardShortcuts.setShortcut(saved, for: .openPanel) }

        let custom = KeyboardShortcuts.Shortcut(.k, modifiers: [.control, .option])
        KeyboardShortcuts.setShortcut(custom, for: .openPanel)

        #expect(KeyboardShortcuts.getShortcut(for: .openPanel) == custom)
    }
}
