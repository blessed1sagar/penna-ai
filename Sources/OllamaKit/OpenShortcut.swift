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
    /// Default is **⌃⌥Space**. The ⌃⌥ pairing is deliberate — a macOS 15 bug
    /// stopped Option-only modifiers from firing, so the default never uses a
    /// bare Option (see docs/implementation-notes.md). Users can rebind it; the
    /// app registers a handler against this name to show/focus the Panel.
    static let openPanel = Self(
        "openPanel",
        default: .init(.space, modifiers: [.control, .option])
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
