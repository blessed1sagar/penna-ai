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
    struct Options: Decodable { let temperature: Double }
    let options: Options?
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

// Slice 5: running in Draft generates new text from the instruction (the input)
// and shows it in the result area. The instruction must reach the model.
@Test @MainActor func runInDraftShowsGeneratedTextFromInstruction() async {
    let recorder = RequestRecorder()
    let model = PanelModel(
        client: clientReturning("Dear landlord, the heating has broken...", recorder: recorder),
        clipboard: FakeClipboard()
    )
    model.selectMode(.draft)
    model.input = "email my landlord about the broken heating"

    await model.run()

    #expect(model.result == "Dear landlord, the heating has broken...")
    let payload = try? JSONDecoder().decode(SentBody.self, from: recorder.request?.httpBody ?? Data())
    #expect(payload?.prompt.contains("email my landlord about the broken heating") == true)
    // Proves the DRAFT brain ran (creative, temp > 0), not Improve (temp 0).
    #expect((payload?.options?.temperature ?? 0) > 0)
}

// Slice 6: Auto-copy. When a Draft completes, the generated text is placed on the
// clipboard automatically so the user can paste it (CONTEXT.md / ADR-0006).
@Test @MainActor func runInDraftAutoCopiesResultToClipboard() async {
    let clipboard = FakeClipboard()
    let model = PanelModel(
        client: clientReturning("Dear landlord, the heating has broken..."),
        clipboard: clipboard
    )
    model.selectMode(.draft)
    model.input = "email my landlord about the broken heating"

    await model.run()

    #expect(clipboard.read() == "Dear landlord, the heating has broken...")
}

// Slice 7: switching FROM Draft back to Improve restores Clipboard auto-fill —
// the input box re-fills from the clipboard (Draft cleared it; leaving Draft
// undoes that). CONTEXT.md: auto-fill applies to Improve/Rephrase, not Draft.
@Test @MainActor func switchingFromDraftBackToImproveRestoresAutoFill() {
    let model = PanelModel(
        client: clientReturning("unused"),
        clipboard: FakeClipboard(contents: "teh cat sat on teh mat")
    )
    model.selectMode(.draft)
    #expect(model.input.isEmpty) // Draft cleared it

    model.selectMode(.improve)

    #expect(model.input == "teh cat sat on teh mat")
}
