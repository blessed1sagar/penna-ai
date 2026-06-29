//
//  PennaApp.swift
//  Penna
//

import SwiftUI
import AppKit
import OllamaKit

@main
struct PennaApp: App {
    // The menu-bar icon, the Panel window, and the global Open shortcut all live
    // in MenuBarController, created at launch. We drive the status item from
    // AppKit (not MenuBarExtra) so the Open shortcut can open/focus the Panel from
    // any app — MenuBarExtra can't be presented programmatically (issue #14).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app has no main window — it's a Dock-less menu-bar agent (ADR-0006,
        // LSUIElement set in target → Info). Settings is an inert scene that keeps
        // SwiftUI's App happy without putting a window on screen. The Open shortcut
        // recorder lives in a window MenuBarController owns and shows itself, not
        // here — SwiftUI's Settings scene can't be opened reliably in a Dock-less
        // app (issue #15).
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        // Warm up the model at launch so the first real run has no cold-start delay
        // (~3–10s to load the 7B model — issue #7). Model residency is server-side,
        // keyed by model name, so a dedicated client here warms the same model the
        // Panel will use. Best-effort: warmUp() swallows errors (Ollama may still be
        // starting), and the Task keeps launch from blocking on it.
        Task { await OllamaClient().warmUp() }
    }
}
