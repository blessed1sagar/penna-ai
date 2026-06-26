import Testing
import Foundation
@testable import OllamaKit

// Slice 1 (tracer bullet): a stream:false /api/generate response is a SINGLE
// JSON object with a "response" field. The client must return that text — and
// must not choke trying to read it as line-delimited (NDJSON) streaming output.
@Test func returnsTextFromNonStreamingResponse() async throws {
    let body = Data(#"""
    {"model":"qwen2.5:7b-instruct-q4_K_M","created_at":"2026-06-24T00:00:00Z","response":"Hello, world.","done":true}
    """#.utf8)

    // Fake "way to fetch": no real network, just hand back the canned body.
    let client = OllamaClient(transport: { request in
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, http)
    })

    let text = try await client.generate(prompt: "say hi")

    #expect(text == "Hello, world.")
}

// Lets a test capture the request the client tried to send.
// @unchecked Sendable: we only touch it after generate() returns, single-threaded.
private final class RequestRecorder: @unchecked Sendable {
    var request: URLRequest?
}

// The shape we expect the client to POST to Ollama.
private struct SentRequest: Decodable {
    let model: String
    let prompt: String
    let stream: Bool
}

// Slice 2: the request must be a POST to /api/generate carrying the model name,
// the prompt, and stream:false (so Ollama returns ONE object, not an NDJSON stream).
@Test func sendsNonStreamingPostToGenerateEndpoint() async throws {
    let body = Data(#"{"response":"ok","done":true}"#.utf8)
    let recorder = RequestRecorder()

    let client = OllamaClient(model: "qwen2.5:7b-instruct-q4_K_M", transport: { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, http)
    })

    _ = try await client.generate(prompt: "fix this sentence")

    let sent = try #require(recorder.request)
    #expect(sent.httpMethod == "POST")
    #expect(sent.url?.path == "/api/generate")

    let payload = try JSONDecoder().decode(SentRequest.self, from: #require(sent.httpBody))
    #expect(payload.model == "qwen2.5:7b-instruct-q4_K_M")
    #expect(payload.prompt == "fix this sentence")
    #expect(payload.stream == false)
}

// Slice 3: a non-OK HTTP status (e.g. 404 when the model isn't installed) must
// throw a clear, identifiable error instead of mis-decoding the error body.
@Test func throwsClearErrorOnNonOKStatus() async throws {
    let client = OllamaClient(transport: { request in
        let http = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"error":"model not found"}"#.utf8), http)
    })

    await #expect(throws: OllamaError.httpStatus(404)) {
        _ = try await client.generate(prompt: "hi")
    }
}
