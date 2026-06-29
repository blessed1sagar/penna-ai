//
//  LaunchAtLogin.swift
//  OllamaKit
//
//  "Launch at login" backed by SMAppService (issue #30).
//

import ServiceManagement

/// Launch-at-login control, backed by Apple's `SMAppService.mainApp` — the modern
/// (macOS 13+) replacement for the deprecated `SMLoginItemSetEnabled`. Registering
/// `.mainApp` adds the running app itself as a login item; macOS launches it at
/// login and (because Penna is `LSUIElement`) it comes up Dock-less, straight to
/// the menu bar.
///
/// No special entitlement is required: `SMAppService.mainApp` works with the app's
/// own (even ad-hoc) signature and bundle identifier — which is exactly what issue
/// #30 needs, since Penna ships ad-hoc signed with no Developer ID. The dependency
/// on ServiceManagement is kept here in the testable package (mirroring
/// `OpenShortcut`) so the Xcode app never imports it directly (ADR-0007).
///
/// Wrapped as an enum of static calls rather than free functions so the Settings
/// view reads `LaunchAtLogin.isEnabled` / `setEnabled(_:)` as one named capability,
/// and so the `SMAppService` surface this app uses sits behind one seam.
public enum LaunchAtLogin {
    /// Whether the app is currently registered to launch at login.
    ///
    /// Reads the live registration status from `SMAppService`, so the toggle always
    /// reflects reality — including the case where the user removed Penna from
    /// System Settings ▸ General ▸ Login Items, which flips this back to `false`
    /// without the app doing anything.
    @MainActor public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Turn launch-at-login on (`register`) or off (`unregister`).
    ///
    /// Throwing rather than swallowing: the Settings toggle surfaces a failure to
    /// the user and re-reads `isEnabled` so the switch never lies about the real
    /// state. Registering when already registered (or unregistering when not) is
    /// a harmless no-op as far as the user-visible end state is concerned.
    @MainActor public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
