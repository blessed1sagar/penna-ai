import Testing
import Foundation
@testable import OllamaKit

// A fake clipboard: an in-memory stand-in for the macOS pasteboard, so tests can
// set "what's on the clipboard" and inspect what the Panel writes back — no real
// pasteboard, no AppKit, no global state. Mirrors the Transport fake-seam pattern.
private final class FakeClipboard: Clipboard {
    var contents: String?
    init(contents: String? = nil) { self.contents = contents }
    func read() -> String? { contents }
    func write(_ text: String) { contents = text }
}

// Captures the request the client tried to send, so a test can prove the model
// was (or was NOT) called. @unchecked Sendable: only read after run() returns.
private final class RequestRecorder: @unchecked Sendable {
    var request: URLRequest?
}

// Builds a client whose fake transport returns one canned corrected text, and
// (optionally) records the outgoing request.
private func clientReturning(_ response: String, recorder: RequestRecorder? = nil) -> OllamaClient {
    OllamaClient(transport: { request in
        recorder?.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"response":"\#(response)","done":true}"#.utf8), http)
    })
}

// Slice 1 (tracer bullet): Clipboard auto-fill. Opening the Panel in Improve mode
// prefills the input box with whatever is already on the clipboard — a read of the
// existing clipboard, not a synthetic copy (ADR-0006 / CONTEXT.md).
@Test @MainActor func autoFillPrefillsInputFromClipboardInImprove() {
    let model = PanelModel(
        client: clientReturning("unused"),
        clipboard: FakeClipboard(contents: "teh cat sat on teh mat")
    )

    model.prefillFromClipboard()

    #expect(model.input == "teh cat sat on teh mat")
}

// Slice 2: running Improve sends the input to the model and shows the corrected
// text in the result area.
@Test @MainActor func runShowsCorrectedTextInResult() async {
    let model = PanelModel(
        client: clientReturning("The cat sat on the mat."),
        clipboard: FakeClipboard()
    )
    model.input = "teh cat sat on teh mat"

    await model.run()

    #expect(model.result == "The cat sat on the mat.")
}

// Slice 3: Auto-copy. When generation completes, the result is placed on the
// clipboard automatically so the user can paste it (CONTEXT.md / ADR-0006).
@Test @MainActor func runAutoCopiesResultToClipboard() async {
    let clipboard = FakeClipboard()
    let model = PanelModel(
        client: clientReturning("The cat sat on the mat."),
        clipboard: clipboard
    )
    model.input = "teh cat sat on teh mat"

    await model.run()

    #expect(clipboard.read() == "The cat sat on the mat.")
}

// Slice 4: when Ollama is unreachable (not running), running shows a clear error
// message instead of hanging or crashing, and leaves the result area empty.
@Test @MainActor func runShowsClearErrorWhenOllamaUnreachable() async {
    let model = PanelModel(
        client: OllamaClient(transport: { _ in throw URLError(.cannotConnectToHost) }),
        clipboard: FakeClipboard()
    )
    model.input = "teh cat sat on teh mat"

    await model.run()

    #expect(model.errorMessage?.isEmpty == false)
    #expect(model.result.isEmpty)
}

// Slice 5: empty (or whitespace-only) input must NOT call the model — there's
// nothing to improve, so the run path never reaches the network.
@Test @MainActor func runDoesNotCallModelOnEmptyInput() async {
    let recorder = RequestRecorder()
    let model = PanelModel(
        client: clientReturning("should never be returned", recorder: recorder),
        clipboard: FakeClipboard()
    )
    model.input = "   \n\t  "

    await model.run()

    #expect(recorder.request == nil)
}
