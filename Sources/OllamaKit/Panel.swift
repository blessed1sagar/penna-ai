import Combine

/// The three things the Panel can do to text (ADR-0006):
/// - `improve`  — minimal grammar / spelling / punctuation correction
/// - `rephrase` — deliberate rewording
/// - `draft`    — generate new text from a typed instruction
// Hashable (not just Equatable) so SwiftUI's Picker can use a Mode as the
// selection value and tag. Hashable refines Equatable, so existing == still holds.
public enum Mode: Hashable, CaseIterable {
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

    /// The placeholder shown in the empty input box. Improve/Rephrase work on
    /// existing text (auto-filled or pasted); Draft takes an instruction
    /// describing what to write (CONTEXT.md). Kept here so the view reads it from
    /// one source of truth rather than hard-coding strings.
    public var placeholder: String {
        switch self {
        case .improve, .rephrase: "Paste or type text…"
        case .draft: "Tell me what to write…"
        }
    }
}

/// The state and behaviour behind the Panel UI, kept here (in the testable Swift
/// package) rather than inside the SwiftUI view, per ADR-0007. It's an
/// `ObservableObject` (not a struct) so the SwiftUI view can watch it and the
/// async run logic has a stable home; `@MainActor` because it drives the UI.
@MainActor
public final class PanelModel: ObservableObject {
    /// Which mode the Panel is currently in. Starts on Improve.
    @Published public var selectedMode: Mode = .improve

    /// The text being worked on. Filled by Clipboard auto-fill, or typed.
    @Published public var input: String = ""

    /// The model's finished output, shown in the result area.
    @Published public var result: String = ""

    /// A clear, user-facing message when a run can't complete (e.g. Ollama isn't
    /// running), or nil when there's nothing wrong.
    @Published public var errorMessage: String? = nil

    private let client: OllamaClient
    private let clipboard: Clipboard

    public init(
        client: OllamaClient = OllamaClient(),
        clipboard: Clipboard = SystemClipboard()
    ) {
        self.client = client
        self.clipboard = clipboard
    }

    /// Switch the Panel to `mode` and apply the side effect that depends on the
    /// mode change — which is why the view calls this instead of binding the
    /// Picker straight to `selectedMode`. Switching INTO Draft clears the input
    /// box (Draft takes a typed instruction, never clipboard text — CONTEXT.md).
    public func selectMode(_ mode: Mode) {
        selectedMode = mode
        if mode == .draft {
            input = ""
        } else {
            // Leaving Draft (or moving between auto-fill modes) restores Clipboard
            // auto-fill. prefillFromClipboard enforces which modes actually fill,
            // so Rephrase (#11) extends behaviour there, not here.
            prefillFromClipboard()
        }
    }

    /// Clipboard auto-fill: prefill the input box from the current clipboard
    /// contents. Only in Improve (issue #10) — Rephrase auto-fill is issue #11,
    /// and Draft never auto-fills (CONTEXT.md).
    public func prefillFromClipboard() {
        guard selectedMode == .improve else { return }
        input = clipboard.read() ?? ""
    }

    /// Run the current mode on the input: send it to the model and show the
    /// result. Improve corrects the text; Draft generates new text from the
    /// instruction (the input). Rephrase is a sibling agent's job (#11) — until
    /// it's wired it falls back to Improve so the build stays green.
    public func run() async {
        errorMessage = nil
        do {
            switch selectedMode {
            case .draft:
                result = try await client.draft(instruction: input)
            case .improve, .rephrase:
                result = try await client.improve(text: input)
            }
            // Auto-copy: put the finished result on the clipboard so the user can paste it.
            clipboard.write(result)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Turns a raw error into a clear, user-facing message — never leaks a
    /// low-level error and never just hangs.
    private static func message(for error: Error) -> String {
        switch error {
        case OllamaError.unreachable:
            return "Couldn’t reach Ollama. Make sure it’s running, then try again."
        case OllamaError.httpStatus:
            return "Ollama returned an error. Check that the model is installed."
        case OllamaError.emptyInput:
            return "Enter some text first."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
