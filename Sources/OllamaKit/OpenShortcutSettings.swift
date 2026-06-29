//
//  OpenShortcutSettings.swift
//  OllamaKit
//
//  The Settings screen: rebind the Open shortcut (issue #15) and toggle
//  launch-at-login (issue #30).
//

import SwiftUI
import KeyboardShortcuts

/// A Settings pane with a recorder for the Open shortcut and a launch-at-login
/// toggle. Drop it into the window the menu-bar controller presents; the app never
/// imports KeyboardShortcuts or ServiceManagement itself.
///
/// The recorder binds the same `.openPanel` name that the live hotkey handler
/// registers against (`OpenShortcut.onTrigger`) and that KeyboardShortcuts
/// persists under. One name, one source of truth — so a new binding takes effect
/// immediately and survives a restart, no extra wiring (issue #15).
///
/// The launch-at-login toggle is backed by `LaunchAtLogin` (SMAppService). The
/// switch is driven from the *live* registration status, not a stored boolean, so
/// it always reflects reality — including the user removing Penna from System
/// Settings ▸ Login Items behind the app's back (issue #30).
public struct OpenShortcutSettings: View {
    // Mirrors the live SMAppService status. Seeded from it on appear and re-read
    // after every toggle, so the switch can never drift from the real state. We
    // drive the Toggle through an explicit Binding (rather than binding straight to
    // this @State) so flipping the switch runs register/unregister as a side effect
    // and then re-syncs — and so a failed (or no-op) registration snaps the switch
    // back to the truth instead of showing a state we didn't actually reach.
    @State private var launchAtLogin = false

    public init() {}

    public var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Open Penna:", name: .openPanel)

            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in setLaunchAtLogin(newValue) }
            ))
        }
        .padding(20)
        .frame(width: 350)
        // Seed from the live status when the pane opens — not from a saved flag —
        // so reopening Settings always shows the true current state.
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }

    /// Apply a toggle: register/unregister, then re-read the live status so the
    /// switch reflects what actually happened. If SMAppService throws, the catch
    /// still re-syncs, so the switch falls back to the truth rather than the
    /// attempted value.
    private func setLaunchAtLogin(_ enabled: Bool) {
        try? LaunchAtLogin.setEnabled(enabled)
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
