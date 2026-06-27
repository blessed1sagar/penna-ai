//
//  PennaApp.swift
//  Penna
//

import SwiftUI

@main
struct PennaApp: App {
    var body: some Scene {
        // MenuBarExtra is the whole app: a single menu-bar icon, no main window.
        // Combined with the LSUIElement setting (target → Info), this makes Penna
        // a Dock-less menu-bar agent (ADR-0006).
        MenuBarExtra("Penna", systemImage: "pencil") {
            PanelView()
        }
        // .window style makes clicking the icon open a small floating panel (room
        // for our text boxes and buttons) instead of a plain dropdown menu.
        .menuBarExtraStyle(.window)
    }
}
