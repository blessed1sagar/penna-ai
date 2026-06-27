import Foundation

extension OllamaClient {
    /// Rewords and restructures the user's text to say the same thing differently,
    /// even when the original was already correct, and returns the reworded text.
    ///
    /// This is the "Rephrase" mode brain (ADR-0006): deliberate rewording, in
    /// contrast to Improve, which only fixes what's broken.
    public func rephrase(text: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.emptyInput
        }

        let prompt = """
        Reword and restructure the text below so it says the same thing in a \
        different way. Preserve the meaning but change the wording and sentence \
        structure. Return only the reworded text, with no commentary or quotation marks.

        \(text)
        """
        return try await generate(prompt: prompt, temperature: 0.7)
    }

    /// Streaming "Rephrase" brain: same rewording prompt and temperature as
    /// `rephrase`, but yields the reworded text PROGRESSIVELY (cumulative
    /// snapshots) so the Panel can show it as the model generates. Rejects blank
    /// input up front, before any model call, exactly like `rephrase`.
    public func rephraseStream(text: String) -> AsyncThrowingStream<String, Error> {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: OllamaError.emptyInput) }
        }

        let prompt = """
        Reword and restructure the text below so it says the same thing in a \
        different way. Preserve the meaning but change the wording and sentence \
        structure. Return only the reworded text, with no commentary or quotation marks.

        \(text)
        """
        return generateStream(prompt: prompt, temperature: 0.7)
    }
}
