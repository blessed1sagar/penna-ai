import Foundation

// Each mode is just DATA — a prompt template plus a temperature. The Panel-facing
// bits of `Mode` (title, placeholder) live with the enum in Panel.swift; these
// inference-facing bits live next to the OllamaClient path that consumes them, so
// adding a mode means adding a case here, not a new near-duplicate file (#36).
extension Mode {
    /// How much randomness the model gets for this mode. Improve must be
    /// deterministic (0) so the same input always yields the same correction;
    /// Rephrase and Draft want natural variety, so they run warmer (ADR-0006).
    var temperature: Double {
        switch self {
        case .improve: 0
        case .rephrase, .draft: 0.7
        }
    }

    /// Builds the full prompt sent to the model for this mode, embedding the
    /// user's text/instruction. Improve and Rephrase transform existing text;
    /// Draft writes new text from an instruction (CONTEXT.md / ADR-0006).
    func prompt(for userText: String) -> String {
        switch self {
        case .improve:
            return """
            Fix only the grammar, spelling, and punctuation of the text below. \
            Keep the original wording and meaning. Return only the corrected text, \
            with no commentary or quotation marks.

            \(userText)
            """
        case .rephrase:
            return """
            Reword and restructure the text below so it says the same thing in a \
            different way. Preserve the meaning but change the wording and sentence \
            structure. Return only the reworded text, with no commentary or quotation marks.

            \(userText)
            """
        case .draft:
            return """
            Write the message described by the instruction below. Return only the \
            message itself, with no commentary, preamble, or quotation marks.

            \(userText)
            """
        }
    }
}

extension OllamaClient {
    /// The single mode-driven generation path: reject blank input up front (one
    /// place, not once per mode), then run the mode's prompt at its temperature.
    /// The per-mode methods below are thin sugar over this.
    public func generate(mode: Mode, userText: String) async throws -> String {
        guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.emptyInput
        }
        return try await generate(prompt: mode.prompt(for: userText), temperature: mode.temperature)
    }

    /// Streaming counterpart of `generate(mode:userText:)`: the single mode-driven
    /// stream path. The blank-input guard lives here once (not once per mode) and
    /// finishes the stream with .emptyInput before any model call.
    public func generateStream(mode: Mode, userText: String) -> AsyncThrowingStream<String, Error> {
        guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: OllamaError.emptyInput) }
        }
        return generateStream(prompt: mode.prompt(for: userText), temperature: mode.temperature)
    }

    // MARK: - Per-mode sugar
    //
    // The named entry points kept for callers (and the Panel). Each is now a thin
    // wrapper over the unified path above — the prompt, temperature, and
    // blank-input guard all come from one place (#36). Adding a mode means adding
    // a `Mode` case + its data, not a new near-duplicate method here.

    /// "Improve" mode: minimal grammar/spelling/punctuation correction (ADR-0006).
    public func improve(text: String) async throws -> String {
        try await generate(mode: .improve, userText: text)
    }

    /// Streaming "Improve": progressive corrected text (cumulative snapshots).
    public func improveStream(text: String) -> AsyncThrowingStream<String, Error> {
        generateStream(mode: .improve, userText: text)
    }

    /// "Rephrase" mode: deliberate rewording of existing text (ADR-0006).
    public func rephrase(text: String) async throws -> String {
        try await generate(mode: .rephrase, userText: text)
    }

    /// Streaming "Rephrase": progressive reworded text (cumulative snapshots).
    public func rephraseStream(text: String) -> AsyncThrowingStream<String, Error> {
        generateStream(mode: .rephrase, userText: text)
    }

    /// "Draft" mode: generate new text from a typed instruction (ADR-0006).
    public func draft(instruction: String) async throws -> String {
        try await generate(mode: .draft, userText: instruction)
    }

    /// Streaming "Draft": progressive generated text (cumulative snapshots).
    public func draftStream(instruction: String) -> AsyncThrowingStream<String, Error> {
        generateStream(mode: .draft, userText: instruction)
    }
}
