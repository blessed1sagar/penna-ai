//
//  OpenShortcutTests.swift
//  OllamaKitTests
//
//  Issue #14 — the global Open shortcut that summons the Panel.
//

import Testing
import KeyboardShortcuts
@testable import OllamaKit

@Suite struct OpenShortcutTests {
    // The default Open shortcut is ⌃⌥P. We assert the default — not the user's
    // current binding — so this stays a stable spec even after rebinding.
    private var defaultShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.Name.openPanel.defaultShortcut
    }

    @Test func openPanelHasADefaultShortcut() {
        #expect(defaultShortcut != nil)
    }

    // The key is a letter, not Space: Space-based combos are reserved by macOS
    // (Spotlight, input-source, emoji, Finder) and silently fail to register.
    @Test func defaultShortcutKeyIsP() {
        #expect(defaultShortcut?.key == .p)
    }

    @Test func defaultShortcutKeyIsNotSpace() {
        #expect(defaultShortcut?.key != .space)
    }

    @Test func defaultShortcutUsesControlAndOption() {
        #expect(defaultShortcut?.modifiers.contains(.control) == true)
        #expect(defaultShortcut?.modifiers.contains(.option) == true)
    }

    // Regression guard for the macOS 15 bug where Option-only modifiers stopped
    // firing (see docs/implementation-notes.md). The default must never be a
    // bare Option (or any single-modifier) combo.
    @Test func defaultShortcutIsNotOptionOnly() {
        #expect(defaultShortcut?.modifiers != [.option])
    }
}
