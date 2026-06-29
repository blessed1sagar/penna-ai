import Testing
import Foundation
@testable import OllamaKit

// Lets a test capture the request the client tried to send.
// @unchecked Sendable: only read after the call returns, single-threaded.
private final class BodyRecorder: @unchecked Sendable {
    var body: Data?
    var url: URL?
}

// The fields we assert on: keep_alive pins the model in memory so it stays
// resident between runs (issue #7 — no cold-start delay after the first load).
private struct SentBody: Decodable {
    let prompt: String
    let stream: Bool
    let keep_alive: Int?
}

// Slice 1: generate() must carry keep_alive: -1 — Ollama reads -1 as "keep this
// model loaded indefinitely", so the 7B model stays warm between runs instead of
// being evicted (cold load is ~3–10s).
@Test func generateSetsKeepAliveForever() async throws {
    let recorder = BodyRecorder()
    let client = OllamaClient(transport: { request in
        recorder.body = request.httpBody
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"response":"ok","done":true}"#.utf8), http)
    })

    _ = try await client.generate(prompt: "hi")

    let sent = try JSONDecoder().decode(SentBody.self, from: #require(recorder.body))
    #expect(sent.keep_alive == -1)
}

// Slice 2: the streaming path sends the same personal text and must keep the
// model resident too — generateStream() must carry keep_alive: -1 in its body.
@Test func generateStreamSetsKeepAliveForever() async throws {
    let recorder = BodyRecorder()
    let client = OllamaClient(streamingTransport: { request in
        recorder.body = request.httpBody
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield(#"{"response":"ok","done":true}"#)
            continuation.finish()
        }
        return (stream, http)
    })

    for try await _ in client.generateStream(prompt: "hi") {}

    let sent = try JSONDecoder().decode(SentBody.self, from: #require(recorder.body))
    #expect(sent.keep_alive == -1)
    #expect(sent.stream == true)
}
