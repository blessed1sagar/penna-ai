import Testing
import Foundation
@testable import OllamaKit

// Captures the request warmUp() tried to send.
// @unchecked Sendable: read only after warmUp() returns, single-threaded.
private final class WarmUpRecorder: @unchecked Sendable {
    var request: URLRequest?
    var called = false
}

private struct WarmUpBody: Decodable {
    let model: String
    let stream: Bool
    let keep_alive: Int?
}

// Slice 1 (tracer): warmUp() fires one load request — a POST to /api/generate
// carrying keep_alive: -1 — so the model is pulled into memory at launch and the
// first real run has no cold-start delay (issue #7).
@Test func warmUpLoadsModelWithKeepAliveForever() async throws {
    let recorder = WarmUpRecorder()
    let client = OllamaClient(transport: { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"response":"","done":true}"#.utf8), http)
    })

    await client.warmUp()

    let sent = try #require(recorder.request)
    #expect(sent.httpMethod == "POST")
    #expect(sent.url?.path == "/api/generate")
    let body = try JSONDecoder().decode(WarmUpBody.self, from: #require(sent.httpBody))
    #expect(body.keep_alive == -1)
    #expect(body.model == "qwen2.5:7b-instruct-q4_K_M")
}

// Slice 2: warm-up is best-effort. If Ollama isn't running yet at launch, warmUp()
// must NOT throw — the first real run surfaces the clear "couldn't reach" error;
// launch should never fail because the server is still starting.
@Test func warmUpSwallowsUnreachableServer() async throws {
    let client = OllamaClient(transport: { _ in
        throw URLError(.cannotConnectToHost)
    })

    // No throw expected — this simply returns.
    await client.warmUp()
}

// Slice 3: the loopback guard applies to warm-up too (ADR-0001). A non-loopback
// baseURL must mean the transport is never touched — nothing leaves the machine,
// not even a warm-up.
@Test func warmUpRefusesNonLoopbackHost() async throws {
    let recorder = WarmUpRecorder()
    let client = OllamaClient(
        baseURL: URL(string: "http://evil.example.com")!,
        transport: { request in
            recorder.called = true
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), http)
        }
    )

    await client.warmUp()

    #expect(recorder.called == false)
}
