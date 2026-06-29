import Testing
import Foundation
@testable import OllamaKit

// Lets a test capture the request the client tried to send, so we can assert the
// model was actually shown the user's text and the right knobs.
// @unchecked Sendable: only read after the call returns, single-threaded.
private final class ModeRecorder: @unchecked Sendable {
    var request: URLRequest?
}

// Just the fields we want to inspect from the outgoing JSON body.
private struct ModeSentBody: Decodable {
    let prompt: String
    struct Options: Decodable { let temperature: Double }
    let options: Options
}

// Builds a client whose transport records the request and returns a canned body.
private func recordingClient(_ recorder: ModeRecorder, response: String = "ok") -> OllamaClient {
    OllamaClient(transport: { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"response":"\#(response)","done":true}"#.utf8), http)
    })
}

// Slice 1 (tracer bullet): the unified, mode-driven path returns the model's
// output and shows the model the user's text — for any mode. This proves the one
// parametric path works end-to-end, the same way the three per-mode methods did.
@Test func unifiedGenerateReturnsOutputAndShowsModelTheInput() async throws {
    let recorder = ModeRecorder()
    let client = recordingClient(recorder, response: "He and I went to the store.")

    let output = try await client.generate(mode: .improve, userText: "me and him goes to the store")

    #expect(output == "He and I went to the store.")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(ModeSentBody.self, from: #require(sent.httpBody))
    #expect(payload.prompt.contains("me and him goes to the store"))
}

// Slice 2: the temperature is the MODE's, carried through the unified path —
// Improve is deterministic (0) while Rephrase and Draft run warm (> 0) for
// natural variety. We assert "0" vs "> 0", not exact warm values: the exact
// number is a tuning knob, not behavior (mirrors the per-mode tests).
@Test(arguments: [Mode.improve, .rephrase, .draft])
func unifiedGenerateUsesTheModesTemperature(mode: Mode) async throws {
    let recorder = ModeRecorder()
    let client = recordingClient(recorder)

    _ = try await client.generate(mode: mode, userText: "hello")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(ModeSentBody.self, from: #require(sent.httpBody))
    switch mode {
    case .improve: #expect(payload.options.temperature == 0)
    case .rephrase, .draft: #expect(payload.options.temperature > 0)
    }
}

// Slice 3: the blank-input guard lives in ONE place on the unified path, so it
// holds for every mode — whitespace-only input throws .emptyInput and never
// reaches the model.
@Test(arguments: [Mode.improve, .rephrase, .draft])
func unifiedGenerateRejectsBlankInputWithoutCallingModel(mode: Mode) async throws {
    let recorder = ModeRecorder()
    let client = recordingClient(recorder) // must never be reached for blank input

    await #expect(throws: OllamaError.emptyInput) {
        _ = try await client.generate(mode: mode, userText: "   \n\t  ")
    }

    #expect(recorder.request == nil)
}

// A recording streaming transport: captures the outgoing request (so we can
// inspect the body) and replays canned NDJSON lines, mirroring the fake-seam
// pattern in StreamingGenerateTests.
private func recordingStreamingTransport(
    _ recorder: ModeRecorder,
    lines: [String]
) -> StreamingTransport {
    return { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let stream = AsyncThrowingStream<String, Error> { continuation in
            for line in lines { continuation.yield(line) }
            continuation.finish()
        }
        return (stream, http)
    }
}

private func collectSnapshots(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
    var snapshots: [String] = []
    for try await snapshot in stream { snapshots.append(snapshot) }
    return snapshots
}

// Slice 4 (streaming tracer): the unified, mode-driven STREAMING path accumulates
// the model's text progressively and carries the mode's temperature — proving the
// one parametric stream path works end-to-end like the three per-mode streams did.
@Test func unifiedGenerateStreamAccumulatesTextAndCarriesTemperature() async throws {
    let recorder = ModeRecorder()
    let lines = [
        #"{"response":"We will ","done":false}"#,
        #"{"response":"reconvene.","done":true}"#,
    ]
    let client = OllamaClient(streamingTransport: recordingStreamingTransport(recorder, lines: lines))

    let snapshots = try await collectSnapshots(client.generateStream(mode: .rephrase, userText: "let's meet again"))

    #expect(snapshots.last == "We will reconvene.")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(ModeSentBody.self, from: #require(sent.httpBody))
    #expect(payload.prompt.contains("let's meet again"))
    #expect(payload.options.temperature > 0)
}

// Slice 5: the streaming blank-input guard also lives in ONE place, so for every
// mode a whitespace-only input finishes the stream with .emptyInput and never
// opens a connection to the model.
@Test(arguments: [Mode.improve, .rephrase, .draft])
func unifiedGenerateStreamRejectsBlankInputWithoutCallingModel(mode: Mode) async throws {
    let recorder = ModeRecorder()
    // Transport must never be reached for blank input.
    let client = OllamaClient(streamingTransport: recordingStreamingTransport(recorder, lines: [
        #"{"response":"unexpected","done":true}"#
    ]))

    await #expect(throws: OllamaError.emptyInput) {
        _ = try await collectSnapshots(client.generateStream(mode: mode, userText: "   \n\t  "))
    }

    #expect(recorder.request == nil)
}
