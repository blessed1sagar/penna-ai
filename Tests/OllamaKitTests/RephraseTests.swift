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
