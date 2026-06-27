import Foundation

/// The seam the Panel uses to touch the system clipboard, so the run logic stays
/// unit-testable (ADR-0007): tests inject a fake, the app uses `SystemClipboard`.
/// Two operations only — read what's there (for Clipboard auto-fill) and write a
/// result (for Auto-copy). We never read or write any other app, only the clipboard.
public protocol Clipboard {
    /// The current clipboard text, or nil if it holds no text.
    func read() -> String?
    /// Replaces the clipboard contents with `text`.
    func write(_ text: String)
}

#if canImport(AppKit)
import AppKit

/// The real clipboard, backed by the macOS pasteboard.
public struct SystemClipboard: Clipboard {
    public init() {}

    public func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    public func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        // The pasteboard keeps old data until cleared, so wipe before writing.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
#endif
