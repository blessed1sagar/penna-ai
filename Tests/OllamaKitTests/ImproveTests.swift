import Testing
import Foundation
@testable import OllamaKit

// Lets a test capture the request the client tried to send, so we can assert
// the model was actually shown the user's text.
// @unchecked Sendable: only read after improve() returns, single-threaded.
private final class ImproveRecorder: @unchecked Sendable {
    var request: URLRequest?
}

// Just the field we want to inspect from the outgoing JSON body.
private struct ImproveSentBody: Decodable {
    let prompt: String
}

// The Ollama options block we expect Improve to send.
private struct ImproveSentOptions: Decodable {
    struct Options: Decodable { let temperature: Double }
    let options: Options
}

// Slice 1 (tracer bullet): improve(text:) asks the model to correct the text and
// returns the model's corrected output. The outgoing request must carry the
// user's text (otherwise the model couldn't possibly correct it). We do NOT
// assert the exact instruction wording — that's phrasing, not behavior.
@Test func improveReturnsCorrectedTextAndShowsModelTheInput() async throws {
    let body = Data(#"{"response":"He and I went to the store yesterday.","done":true}"#.utf8)
    let recorder = ImproveRecorder()

    let client = OllamaClient(transport: { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, http)
    })

    let corrected = try await client.improve(text: "me and him goes to the store yesterday")

    #expect(corrected == "He and I went to the store yesterday.")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(ImproveSentBody.self, from: #require(sent.httpBody))
    #expect(payload.prompt.contains("me and him goes to the store yesterday"))
}

// Slice 2: Improve must be deterministic — the request carries temperature 0 so
// the same input always yields the same correction (no random rewording).
@Test func improveRequestIsDeterministic() async throws {
    let body = Data(#"{"response":"ok","done":true}"#.utf8)
    let recorder = ImproveRecorder()

    let client = OllamaClient(transport: { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, http)
    })

    _ = try await client.improve(text: "hello")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(ImproveSentOptions.self, from: #require(sent.httpBody))
    #expect(payload.options.temperature == 0)
}

// Slice 3: empty or whitespace-only input must NOT call the model — it throws a
// clear .emptyInput error so the UI can prompt the user instead of waiting on a
// pointless model call.
@Test func improveRejectsEmptyInputWithoutCallingModel() async throws {
    let recorder = ImproveRecorder()

    let client = OllamaClient(transport: { request in
        recorder.request = request // must never be reached for blank input
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"response":"ok","done":true}"#.utf8), http)
    })

    await #expect(throws: OllamaError.emptyInput) {
        _ = try await client.improve(text: "   \n\t  ")
    }

    #expect(recorder.request == nil)
}

// Slice 4: when Ollama isn't running, the underlying network call fails with a
// cryptic URLError. Improve must surface a clear .unreachable error so the UI can
// say "Ollama isn't running" instead of leaking a low-level error or hanging.
@Test func improveSurfacesUnreachableWhenOllamaIsDown() async throws {
    let client = OllamaClient(transport: { _ in
        throw URLError(.cannotConnectToHost)
    })

    await #expect(throws: OllamaError.unreachable) {
        _ = try await client.improve(text: "hello")
    }
}
