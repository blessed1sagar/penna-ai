import Testing
import Foundation
@testable import OllamaKit

// A fake clipboard: an in-memory stand-in for the macOS pasteboard, so tests can
// set "what's on the clipboard" and inspect what the Panel writes back.
private final class FakeClipboard: Clipboard {
    var contents: String?
    init(contents: String? = nil) { self.contents = contents }
    func read() -> String? { contents }
    func write(_ text: String) { contents = text }
}

// Captures the request the client tried to send, so a test can prove the model
// was (or was NOT) called with the right content.
private final class RequestRecorder: @unchecked Sendable {
    var request: URLRequest?
}

// Just the field we want to inspect from the outgoing JSON body.
private struct SentBody: Decodable {
    let prompt: String
}

// Builds a client whose fake transport returns one canned text and (optionally)
// records the outgoing request.
private func clientReturning(_ response: String, recorder: RequestRecorder? = nil) -> OllamaClient {
    OllamaClient(transport: { request in
        recorder?.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"response":"\#(response)","done":true}"#.utf8), http)
    })
}

// Slice 3: switching INTO Draft clears the input box. Draft takes a typed
// instruction, not clipboard text, so any auto-filled/typed content is wiped so
// the user starts from a clean instruction (CONTEXT.md: Draft never auto-fills).
@Test @MainActor func switchingIntoDraftClearsInput() {
    let model = PanelModel(
        client: clientReturning("unused"),
        clipboard: FakeClipboard(contents: "teh cat sat on teh mat")
    )
    model.input = "teh cat sat on teh mat"

    model.selectMode(.draft)

    #expect(model.input.isEmpty)
}

// Slice 4: Draft shows an instruction placeholder telling the user to describe
// what to write. The placeholder text lives on the Mode (one source of truth),
// not hard-coded in the view, so the view just reads it.
@Test func draftModeHasAnInstructionPlaceholder() {
    #expect(Mode.draft.placeholder == "Tell me what to write…")
}
