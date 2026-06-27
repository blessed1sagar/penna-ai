import Foundation

extension OllamaClient {
    /// Corrects the user's text — fixing only grammar, spelling, and punctuation
    /// while preserving their wording — and returns the corrected text.
    ///
    /// This is the "Improve" mode brain (ADR-0006): minimal correction, not rewording.
    public func improve(text: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.emptyInput
        }

        let prompt = """
        Fix only the grammar, spelling, and punctuation of the text below. \
        Keep the original wording and meaning. Return only the corrected text, \
        with no commentary or quotation marks.

        \(text)
        """
        return try await generate(prompt: prompt, temperature: 0)
    }

    /// Streaming "Improve" brain: same minimal-correction prompt as `improve`,
    /// but yields the corrected text PROGRESSIVELY (cumulative snapshots) so the
    /// Panel can show it as the model generates. Rejects blank input up front,
    /// before any model call, exactly like `improve`.
    public func improveStream(text: String) -> AsyncThrowingStream<String, Error> {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: OllamaError.emptyInput) }
        }

        let prompt = """
        Fix only the grammar, spelling, and punctuation of the text below. \
        Keep the original wording and meaning. Return only the corrected text, \
        with no commentary or quotation marks.

        \(text)
        """
        return generateStream(prompt: prompt, temperature: 0)
    }
}
