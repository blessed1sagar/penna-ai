import Testing
import Foundation
import Combine
@testable import OllamaKit

// A fake clipboard mirroring PanelRunTests: an in-memory pasteboard so a test can
// inspect what (and WHEN) the Panel Auto-copies.
private final class FakeClipboard: Clipboard {
    var contents: String?
    init(contents: String? = nil) { self.contents = contents }
    func read() -> String? { contents }
    func write(_ text: String) { contents = text }
}

// Builds a client whose streaming transport emits the given NDJSON lines one at a
// time, so the Panel receives progressive cumulative snapshots.
private func streamingClient(lines: [String]) -> OllamaClient {
    OllamaClient(streamingTransport: { request in
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let stream = AsyncThrowingStream<String, Error> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
        return (stream, http)
    })
}

// Slice 4: running Improve streams the model's output PROGRESSIVELY into the
// result area — the result grows as NDJSON lines arrive — and ends on the full
// completion. We record every published `result` value to prove it wasn't a
// single final assignment.
@Test @MainActor func runStreamsProgressivelyIntoResult() async {
    let model = PanelModel(
        client: streamingClient(lines: [
            #"{"response":"The ","done":false}"#,
            #"{"response":"cat ","done":false}"#,
            #"{"response":"sat.","done":true}"#,
        ]),
        clipboard: FakeClipboard()
    )
    model.input = "teh cat sat"

    var observed: [String] = []
    let cancellable = model.$result.sink { observed.append($0) }
    defer { cancellable.cancel() }

    await model.run()

    #expect(model.result == "The cat sat.")
    // Saw the text grow, not just one final assignment (initial "" + 3 snapshots).
    #expect(observed.contains("The "))
    #expect(observed.contains("The cat "))
    #expect(observed.last == "The cat sat.")
}

// Lets a test probe state mid-stream: after a partial line is emitted but BEFORE
// the done:true line, the transport asks this probe to snapshot the clipboard, so
// a test can see what the clipboard holds while output is still partial. Holding
// the clipboard reference here (not in the @Sendable transport closure) keeps the
// closure Sendable. @unchecked Sendable: touched only on the main actor.
private final class MidStreamProbe: @unchecked Sendable {
    let clipboard: Clipboard
    var clipboardDuringStream: String?
    init(clipboard: Clipboard) { self.clipboard = clipboard }
    @MainActor func snapshot() { clipboardDuringStream = clipboard.read() }
}

// Slice 5: Auto-copy must fire ONLY once the stream finishes — never on partial
// output. While partial snapshots are arriving, the clipboard stays empty; only
// after completion does the finished result land on it.
@Test @MainActor func autoCopyHappensOnlyAfterStreamCompletes() async {
    let clipboard = FakeClipboard()
    let probe = MidStreamProbe(clipboard: clipboard)

    let client = OllamaClient(streamingTransport: { request in
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let stream = AsyncThrowingStream<String, Error> { continuation in
            Task { @MainActor in
                continuation.yield(#"{"response":"Partial","done":false}"#)
                // Mid-stream: the partial snapshot has been delivered, but the
                // stream is NOT done — Auto-copy must not have happened yet.
                probe.snapshot()
                continuation.yield(#"{"response":" result.","done":true}"#)
                continuation.finish()
            }
        }
        return (stream, http)
    })

    let model = PanelModel(client: client, clipboard: clipboard)
    model.input = "teh partial result"

    await model.run()

    // Nothing was Auto-copied while output was still partial...
    #expect(probe.clipboardDuringStream == nil)
    // ...and the finished result is on the clipboard after completion.
    #expect(clipboard.read() == "Partial result.")
}
