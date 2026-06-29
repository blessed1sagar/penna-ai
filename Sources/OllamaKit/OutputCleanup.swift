import Foundation

/// Removes a conversational wrapper the model sometimes adds around its answer
/// (e.g. "Sure, here's the corrected text:") even though every mode prompt asks
/// for "only the corrected text, no commentary". Belt-and-suspenders for issue #7
/// so only the real content reaches the user.
///
/// Deliberately conservative — it must never eat real content. It strips only a
/// FIRST line that both looks like a known opener AND ends in a colon, plus the
/// blank line that follows. It does no general trimming, so a partial streaming
/// snapshot like "The " passes through untouched.
func stripConversationalWrapper(_ text: String) -> String {
    stripWrappingQuotes(stripPreamble(text))
}

/// Drops a recognized conversational opener line and the blank line after it.
private func stripPreamble(_ text: String) -> String {
    guard let newlineIndex = text.firstIndex(of: "\n") else { return text }
    let firstLine = text[..<newlineIndex].trimmingCharacters(in: .whitespaces)
    guard isConversationalPreamble(firstLine) else { return text }
    let rest = text[text.index(after: newlineIndex)...]
    return String(rest.drop(while: { $0 == "\n" }))
}

/// Removes a single pair of double quotes wrapping the WHOLE answer. Only acts
/// when the quotes are the only two in the string — interior quotes mean separate
/// quoted spans (or a half-open partial snapshot), which we must leave intact.
private func stripWrappingQuotes(_ text: String) -> String {
    guard text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") else { return text }
    let inner = text.dropFirst().dropLast()
    guard !inner.contains("\"") else { return text }
    return String(inner)
}

/// Whether a first line is a conversational opener we should drop: it must end in
/// a colon AND begin with one of these known lead-ins. Requiring a known opener
/// (not just a trailing colon) is what stops us eating a real heading the user
/// wrote, like "Ingredients:".
private func isConversationalPreamble(_ line: String) -> Bool {
    guard line.hasSuffix(":") else { return false }
    let openers = [
        "sure", "certainly", "of course", "okay", "ok",
        "here is", "here's", "here are", "absolutely", "got it", "below",
    ]
    let lowered = line.lowercased()
    return openers.contains { lowered.hasPrefix($0) }
}
