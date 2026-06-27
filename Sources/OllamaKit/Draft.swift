import Foundation

extension OllamaClient {
    /// Generates new text (a message or email) from a typed instruction and
    /// returns it.
    ///
    /// This is the "Draft" mode brain (ADR-0006 / CONTEXT.md): unlike Improve
    /// (which corrects existing text) Draft *creates* text, so it runs at a
    /// non-zero temperature for natural, varied prose — 0.7 gives the model room
    /// to phrase things well without drifting into incoherence.
    public func draft(instruction: String) async throws -> String {
        guard !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.emptyInput
        }

        let prompt = """
        Write the message described by the instruction below. Return only the \
        message itself, with no commentary, preamble, or quotation marks.

        \(instruction)
        """
        return try await generate(prompt: prompt, temperature: 0.7)
    }

    /// Streaming "Draft" brain: same generation prompt and temperature as
    /// `draft`, but yields the generated text PROGRESSIVELY (cumulative snapshots)
    /// so the Panel can show it as the model writes. Rejects a blank instruction
    /// up front, before any model call, exactly like `draft`.
    public func draftStream(instruction: String) -> AsyncThrowingStream<String, Error> {
        guard !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: OllamaError.emptyInput) }
        }

        let prompt = """
        Write the message described by the instruction below. Return only the \
        message itself, with no commentary, preamble, or quotation marks.

        \(instruction)
        """
        return generateStream(prompt: prompt, temperature: 0.7)
    }
}
