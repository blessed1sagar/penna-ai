import Testing
import Foundation
@testable import OllamaKit

// Lets a test capture the request the client tried to send, so we can assert the
// model was actually shown the user's text.
// @unchecked Sendable: only read after rephrase() returns, single-threaded.
private final class RephraseRecorder: @unchecked Sendable {
    var request: URLRequest?
}

// Just the field we want to inspect from the outgoing JSON body.
private struct RephraseSentBody: Decodable {
    let prompt: String
}

// The Ollama options block we expect Rephrase to send.
private struct RephraseSentOptions: Decodable {
    struct Options: Decodable { let temperature: Double }
    let options: Options
}

// Slice 1 (tracer bullet): rephrase(text:) asks the model to reword the text and
// returns the model's reworded output. The outgoing request must carry the user's
// text (otherwise the model couldn't reword it). We do NOT assert the exact
// instruction wording — that's phrasing, not behavior.
@Test func rephraseReturnsRewordedTextAndShowsModelTheInput() async throws {
    let body = Data(#"{"response":"We will reconvene tomorrow morning.","done":true}"#.utf8)
    let recorder = RephraseRecorder()

    let client = OllamaClient(transport: { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, http)
    })

    let reworded = try await client.rephrase(text: "let's meet again tomorrow morning")

    #expect(reworded == "We will reconvene tomorrow morning.")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(RephraseSentBody.self, from: #require(sent.httpBody))
    #expect(payload.prompt.contains("let's meet again tomorrow morning"))
}

// Slice 2: Rephrase needs natural variety, so it must send a temperature greater
// than 0 (Improve sends 0 for determinism). We assert "> 0", not an exact value —
// the exact number is a tuning knob, not behavior.
@Test func rephraseRequestUsesTemperatureAboveZero() async throws {
    let body = Data(#"{"response":"ok","done":true}"#.utf8)
    let recorder = RephraseRecorder()

    let client = OllamaClient(transport: { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, http)
    })

    _ = try await client.rephrase(text: "hello")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(RephraseSentOptions.self, from: #require(sent.httpBody))
    #expect(payload.options.temperature > 0)
}

// Slice 3: empty or whitespace-only input must NOT call the model — it throws a
// clear .emptyInput error so the UI can prompt the user instead of waiting on a
// pointless model call.
@Test func rephraseRejectsEmptyInputWithoutCallingModel() async throws {
    let recorder = RephraseRecorder()

    let client = OllamaClient(transport: { request in
        recorder.request = request // must never be reached for blank input
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"response":"ok","done":true}"#.utf8), http)
    })

    await #expect(throws: OllamaError.emptyInput) {
        _ = try await client.rephrase(text: "   \n\t  ")
    }

    #expect(recorder.request == nil)
}
