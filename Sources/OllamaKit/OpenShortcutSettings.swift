//
//  OpenShortcutSettings.swift
//  OllamaKit
//
//  The Settings screen that lets the user rebind the Open shortcut (issue #15).
//

import SwiftUI
import KeyboardShortcuts

/// A Settings pane with a recorder for the Open shortcut. Drop it into the app's
/// `Settings { }` scene; the app never imports KeyboardShortcuts itself.
///
/// The recorder binds the same `.openPanel` name that the live hotkey handler
/// registers against (`OpenShortcut.onTrigger`) and that KeyboardShortcuts
/// persists under. One name, one source of truth — so a new binding takes effect
/// immediately and survives a restart, no extra wiring (issue #15).
public struct OpenShortcutSettings: View {
    public init() {}

    public var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Open Penna:", name: .openPanel)
        }
        .padding(20)
        .frame(width: 350)
    }
}
