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

    /// Clipboard auto-fill: prefill the input box from the current clipboard
    /// contents. Applies in Improve and Rephrase; Draft never auto-fills, since
    /// its input is an instruction the user types, not text to transform (CONTEXT.md).
    public func prefillFromClipboard() {
        guard selectedMode == .improve || selectedMode == .rephrase else { return }
        input = clipboard.read() ?? ""
    }

    /// Run the current mode on the input: stream the model's output progressively
    /// into the result area, then Auto-copy the finished text. Improve and Rephrase
    /// are wired (#10, #11); Draft (#12) is owned by another slice.
    public func run() async {
        errorMessage = nil
        result = ""
        do {
            // Mode-agnostic streaming consumption: pick the stream for the current
            // mode, then surface each cumulative snapshot into `result` so the text
            // appears progressively as the model generates it.
            for try await snapshot in stream(for: selectedMode) {
                result = snapshot
            }
            // Auto-copy: only ONCE the stream has finished — never on partial output.
            clipboard.write(result)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// The progressive text stream for a given mode. Improve and Rephrase are
    /// wired; Draft (#12) will return its own stream at merge time.
    private func stream(for mode: Mode) -> AsyncThrowingStream<String, Error> {
        switch mode {
        case .improve:
            return client.improveStream(text: input)
        case .rephrase:
            return client.rephraseStream(text: input)
        case .draft:
            // Not wired yet (issue #12). Surface a generic error rather than
            // silently doing nothing if somehow reached.
            return AsyncThrowingStream { $0.finish(throwing: OllamaError.emptyInput) }
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
