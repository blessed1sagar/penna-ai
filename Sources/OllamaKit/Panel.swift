/// The three things the Panel can do to text (ADR-0006):
/// - `improve`  — minimal grammar / spelling / punctuation correction
/// - `rephrase` — deliberate rewording
/// - `draft`    — generate new text from a typed instruction
public enum Mode: Equatable, CaseIterable {
    case improve
    case rephrase
    case draft

    /// The label shown on this mode's button in the selector.
    public var title: String {
        switch self {
        case .improve: "Improve"
        case .rephrase: "Rephrase"
        case .draft: "Draft"
        }
    }
}

/// The state behind the Panel UI, kept here (in the testable Swift package)
/// rather than inside the SwiftUI view, per ADR-0007.
public struct PanelModel {
    /// Which mode the Panel is currently in. Starts on Improve.
    public var selectedMode: Mode = .improve

    public init() {}
}
