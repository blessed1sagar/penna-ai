import Testing
@testable import OllamaKit

// Slice 1 (tracer): the model sometimes wraps its answer in a conversational
// preamble ("Sure, here's the corrected text:") despite the prompt asking it not
// to. Stripping must remove that recognized opener line and the blank line after
// it, leaving only the real content (issue #7, belt-and-suspenders).
@Test func stripsRecognizedPreamble() {
    let wrapped = "Sure, here's the corrected text:\n\nThe cat sat on the mat."
    #expect(stripConversationalWrapper(wrapped) == "The cat sat on the mat.")
}

// Slice 2: a first line that ends in a colon but is NOT a conversational opener
// is real content (e.g. a heading the user actually wants), so it must survive.
// This is the guard against over-stripping — colon alone isn't enough.
@Test func keepsColonLineThatIsNotAPreamble() {
    let content = "Ingredients:\n\n- milk\n- eggs"
    #expect(stripConversationalWrapper(content) == content)
}

// Slice 3: streaming yields CUMULATIVE snapshots, so cleanup runs on every partial
// snapshot. A partial like "The " (no newline yet, trailing space) must pass
// through byte-for-byte — no general trimming — or progressive output would jitter
// and the exact-snapshot streaming tests would break.
@Test func preservesPartialSnapshotVerbatim() {
    #expect(stripConversationalWrapper("The ") == "The ")
    #expect(stripConversationalWrapper("The cat sat.") == "The cat sat.")
}

// Slice 4: the model sometimes wraps the whole answer in double quotes despite
// the prompt forbidding them. A single pair around the entire content is stripped.
@Test func stripsSurroundingQuotes() {
    #expect(stripConversationalWrapper(#""The cat sat.""#) == "The cat sat.")
}

// Slice 5: but only a pair that wraps the WHOLE answer. Content with its own
// interior quotes (two separate quoted spans, or a mid-sentence quote) must be
// left intact — stripping the outer pair there would mangle real text. And a
// half-open partial snapshot (opening quote, no close yet) must pass through.
@Test func keepsInteriorQuotes() {
    #expect(stripConversationalWrapper(#""one" and "two""#) == #""one" and "two""#)
    #expect(stripConversationalWrapper(#"She said "hi" today."#) == #"She said "hi" today."#)
    #expect(stripConversationalWrapper(#""The cat"#) == #""The cat"#)
}
