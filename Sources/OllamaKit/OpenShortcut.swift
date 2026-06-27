//
//  OpenShortcut.swift
//  OllamaKit
//
//  The global Open shortcut that summons the Panel from any app (issue #14).
//

import KeyboardShortcuts

public extension KeyboardShortcuts.Name {
    /// The Open shortcut: a global hotkey that opens and focuses the Panel.
    ///
    /// Default is **⌃⌥P** (P for Penna). The ⌃⌥ pairing is deliberate — a macOS
    /// 15 bug stopped Option-only modifiers from firing, so the default never
    /// uses a bare Option. The key is a letter, not Space: Space-based combos are
    /// a minefield of reserved system shortcuts (Spotlight ⌘Space, input-source
    /// ⌃Space/⌃⌥Space, emoji ⌃⌘Space, Finder ⌥⌘Space). ⌃⌥Space stays reserved at
    /// the Carbon level even when shown disabled, so RegisterEventHotKey fails
    /// silently and the hotkey never fires (see docs/implementation-notes.md).
    /// Users can rebind it; the app registers a handler against this name.
    static let openPanel = Self(
        "openPanel",
        default: .init(.p, modifiers: [.control, .option])
    )
}

/// The global Open shortcut (issue #14). This wrapper keeps the KeyboardShortcuts
/// dependency inside the testable package: the Xcode app registers a handler here
/// without importing KeyboardShortcuts itself.
public enum OpenShortcut {
    /// Register `handler` to run whenever the user presses the Open shortcut.
    /// Call once at app launch with the code that shows/focuses the Panel.
    @MainActor public static func onTrigger(_ handler: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .openPanel, action: handler)
    }
}
