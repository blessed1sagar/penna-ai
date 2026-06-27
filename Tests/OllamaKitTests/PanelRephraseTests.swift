import Testing
import Foundation
@testable import OllamaKit

// In-memory clipboard stand-in (mirrors the FakeClipboard in PanelRunTests).
private final class FakeClipboard: Clipboard {
    var contents: String?
    init(contents: String? = nil) { self.contents = contents }
    func read() -> String? { contents }
    func write(_ text: String) { contents = text }
}

// Captures the outgoing request so a test can prove what the model was sent.
private final class RequestRecorder: @unchecked Sendable {
    var request: URLRequest?
}

// Builds a client whose fake transports return one canned text and (optionally)
// record the outgoing request. Both seams are wired: the non-streaming `transport`
// and the `streamingTransport` that `run()` now uses — the latter emits the canned
// text as a single done:true NDJSON line.
private func clientReturning(_ response: String, recorder: RequestRecorder? = nil) -> OllamaClient {
    let line = #"{"response":"\#(response)","done":true}"#
    return OllamaClient(
        transport: { request in
            recorder?.request = request
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(line.utf8), http)
        },
        streamingTransport: { request in
            recorder?.request = request
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let stream = AsyncThrowingStream<String, Error> { continuation in
                continuation.yield(line)
                continuation.finish()
            }
            return (stream, http)
        }
    )
}

// Slice 4: Clipboard auto-fill in Rephrase. Opening the Panel in Rephrase mode
// prefills the input box with whatever is already on the clipboard — same as
// Improve (CONTEXT.md). Draft never auto-fills.
@Test @MainActor func autoFillPrefillsInputFromClipboardInRephrase() {
    let model = PanelModel(
        client: clientReturning("unused"),
        clipboard: FakeClipboard(contents: "let's meet again tomorrow morning")
    )
    model.selectedMode = .rephrase

    model.prefillFromClipboard()

    #expect(model.input == "let's meet again tomorrow morning")
}

// The options block, to confirm run() in Rephrase took the rephrase path (which
// uses temperature > 0) rather than the improve path (temperature 0).
private struct SentOptions: Decodable {
    struct Options: Decodable { let temperature: Double }
    let options: Options
}

// Slice 5: running in Rephrase mode sends the input to the model via the rephrase
// path and shows the reworded text in the result area. Temperature > 0 proves it
// dispatched to rephrase, not improve.
@Test @MainActor func runInRephraseShowsRewordedTextInResult() async throws {
    let recorder = RequestRecorder()
    let model = PanelModel(
        client: clientReturning("We will reconvene tomorrow morning.", recorder: recorder),
        clipboard: FakeClipboard()
    )
    model.selectedMode = .rephrase
    model.input = "let's meet again tomorrow morning"

    await model.run()

    #expect(model.result == "We will reconvene tomorrow morning.")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(SentOptions.self, from: #require(sent.httpBody))
    #expect(payload.options.temperature > 0)
}

// Slice 6: Auto-copy in Rephrase. When generation completes, the reworded result
// is placed on the clipboard automatically so the user can paste it (CONTEXT.md).
@Test @MainActor func runInRephraseAutoCopiesResultToClipboard() async {
    let clipboard = FakeClipboard()
    let model = PanelModel(
        client: clientReturning("We will reconvene tomorrow morning."),
        clipboard: clipboard
    )
    model.selectedMode = .rephrase
    model.input = "let's meet again tomorrow morning"

    await model.run()

    #expect(clipboard.read() == "We will reconvene tomorrow morning.")
}
