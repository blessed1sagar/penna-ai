//
//  MenuBarController.swift
//  Penna
//
//  Owns the menu-bar icon and the Panel window, and wires up the global Open
//  shortcut (issue #14).
//
//  Why AppKit instead of SwiftUI's MenuBarExtra: the Open shortcut must open and
//  focus the Panel from any frontmost app, and MenuBarExtra exposes no public API
//  to present its popover programmatically. An NSStatusItem + NSPanel that we own
//  outright can be shown by *both* an icon click and the hotkey — the single
//  surface ADR-0006 calls for (a Dock-less menu-bar Panel), just driven by us.
//

import AppKit
import SwiftUI
import OllamaKit

@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    // One model for the app's lifetime, shared with the Panel view. Owning it here
    // (rather than letting the view make its own) lets us refresh the clipboard on
    // every open and keeps the view stable across hide/show.
    private let model = PanelModel()
    // The settings window, created the first time it's opened and kept alive after.
    // We own it directly rather than using SwiftUI's `Settings` scene: that scene's
    // `showSettingsWindow:` command silently fails in a Dock-less menu-bar app (no
    // key window to route the command through), so we present it ourselves — the
    // same way we own the Panel (issue #15).
    private var settingsWindow: NSWindow?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // A borderless-feeling utility panel that can still take keyboard focus
        // (.titled is required for text input to work; we just hide the chrome).
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()

        configureStatusItem()
        configurePanel()

        // The hotkey and the icon both funnel into toggle(), so they share one
        // surface and one behaviour — press once to open, again to close.
        OpenShortcut.onTrigger { [weak self] in self?.toggle() }
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "pencil",
                accessibilityDescription: "Penna"
            )
            // Left-click toggles the Panel (issue #14); right- or control-click
            // pops the menu (issue #15) — the only way to reach Settings in a
            // Dock-less app with no app menu. We route both through one action and
            // branch on the event so a plain click never opens the menu.
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
        let isControlClick = event?.modifierFlags.contains(.control) == true
        if isRightClick || isControlClick {
            showMenu()
        } else {
            toggle()
        }
    }

    /// Pop the status-item menu. Assigning `statusItem.menu` only for the duration
    /// of the click is the standard trick: a persistent menu would hijack the
    /// left-click that must toggle the Panel, so we clear it again immediately.
    private func showMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(
            title: "Open Shortcut…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Penna",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Open the settings window that hosts the shortcut recorder, building it on
    /// first use. We activate first so the window comes to the front from a
    /// Dock-less app. `isReleasedWhenClosed = false` keeps the window object alive
    /// after the user closes it, so a second open reuses it instead of crashing on
    /// a freed window — the standard AppKit gotcha for code-created windows.
    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 140),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Penna Settings"
            window.contentViewController = NSHostingController(rootView: OpenShortcutSettings())
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func configurePanel() {
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        // Build the view once and size the window to its SwiftUI content. Reusing
        // it (instead of rebuilding on each open) avoids an AppKit layout-recursion
        // warning; the clipboard is refreshed in show() instead.
        panel.contentViewController = NSHostingController(rootView: PanelView(model: model))
    }

    /// Toggle the Panel: a second icon click (or hotkey) while it's up hides it.
    @objc private func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    /// Open and focus the Panel — works even when another app is frontmost.
    /// Refreshes the clipboard auto-fill on every open (the view itself is reused).
    private func show() {
        model.prefillFromClipboard()
        positionBelowStatusItem()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Anchor the Panel just under the menu-bar icon, right edges aligned.
    private func positionBelowStatusItem() {
        guard let buttonWindow = statusItem.button?.window else {
            panel.center()
            return
        }
        let buttonFrame = buttonWindow.frame
        let panelSize = panel.frame.size
        let x = buttonFrame.maxX - panelSize.width
        let y = buttonFrame.minY - panelSize.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // Click elsewhere → the Panel dismisses, the expected menu-bar feel.
    func windowDidResignKey(_ notification: Notification) {
        panel.orderOut(nil)
    }
}
