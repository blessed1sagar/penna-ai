import Testing
import Foundation
@testable import OllamaKit

// Lets a test capture the request the client tried to send, so we can assert
// the model was actually shown the user's instruction.
// @unchecked Sendable: only read after draft() returns, single-threaded.
private final class DraftRecorder: @unchecked Sendable {
    var request: URLRequest?
}

// Just the field we want to inspect from the outgoing JSON body.
private struct DraftSentBody: Decodable {
    let prompt: String
}

// The Ollama options block we expect Draft to send.
private struct DraftSentOptions: Decodable {
    struct Options: Decodable { let temperature: Double }
    let options: Options
}

// Slice 1 (tracer bullet): draft(instruction:) asks the model to write new text
// from the instruction and returns the model's generated output. The outgoing
// request must carry the user's instruction (otherwise the model couldn't know
// what to write). We do NOT assert the exact prompt wording — that's phrasing.
@Test func draftReturnsGeneratedTextAndShowsModelTheInstruction() async throws {
    let body = Data(#"{"response":"Dear landlord, the heating in my flat has stopped working...","done":true}"#.utf8)
    let recorder = DraftRecorder()

    let client = OllamaClient(transport: { request in
        recorder.request = request
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, http)
    })

    let generated = try await client.draft(instruction: "email my landlord about the broken heating")

    #expect(generated == "Dear landlord, the heating in my flat has stopped working...")

    let sent = try #require(recorder.request)
    let payload = try JSONDecoder().decode(DraftSentBody.self, from: #require(sent.httpBody))
    #expect(payload.prompt.contains("email my landlord about the broken heating"))
}
