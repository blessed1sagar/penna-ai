import Testing
import Foundation
@testable import OllamaKit

// A fake streaming transport: emits canned NDJSON lines ONE AT A TIME, mirroring
// the synchronous `Transport` fake-seam pattern. This lets streaming tests prove
// the client reads line-by-line (NDJSON) rather than parsing the whole body as a
// single JSON document — the most common streaming bug (implementation-notes.md).
private func streamingTransport(
    lines: [String],
    statusCode: Int = 200
) -> StreamingTransport {
    return { request in
        let http = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        let stream = AsyncThrowingStream<String, Error> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
        return (stream, http)
    }
}

// Drains an AsyncThrowingStream<String> into an ordered array of snapshots.
private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
    var snapshots: [String] = []
    for try await snapshot in stream {
        snapshots.append(snapshot)
    }
    return snapshots
}

// Slice 1 (tracer bullet): a streaming /api/generate reply is NDJSON — one JSON
// object per line, each carrying a partial "response", the last with done:true.
// The streaming API must decode each line and accumulate the response fields, so
// the final emitted text is the whole completion.
@Test func streamingGenerateAccumulatesTextFromNDJSONLines() async throws {
    let lines = [
        #"{"response":"Hello","done":false}"#,
        #"{"response":", ","done":false}"#,
        #"{"response":"world.","done":true}"#,
    ]
    let client = OllamaClient(streamingTransport: streamingTransport(lines: lines))

    let snapshots = try await collect(client.generateStream(prompt: "say hi"))

    #expect(snapshots.last == "Hello, world.")
}

// Slice 2: the stream STOPS at the line carrying done:true. Ollama's final
// NDJSON object (with done:true) holds summary stats and an empty response; any
// bytes after it are not part of the answer. The accumulated text must end at
// done:true and ignore anything that follows.
@Test func streamingGenerateStopsAtDoneTrue() async throws {
    let lines = [
        #"{"response":"Done","done":false}"#,
        #"{"response":".","done":true}"#,
        // Stray trailing line that must NOT be appended to the answer.
        #"{"response":" IGNORED","done":false}"#,
    ]
    let client = OllamaClient(streamingTransport: streamingTransport(lines: lines))

    let snapshots = try await collect(client.generateStream(prompt: "say hi"))

    #expect(snapshots.last == "Done.")
}

// Slice 3: progressive delivery. The caller must see the text GROW — an ordered
// run of intermediate cumulative snapshots, one per NDJSON line — not just the
// final result. This is what makes the Panel show output as it's generated.
@Test func streamingGenerateDeliversProgressiveSnapshots() async throws {
    let lines = [
        #"{"response":"The ","done":false}"#,
        #"{"response":"cat ","done":false}"#,
        #"{"response":"sat.","done":true}"#,
    ]
    let client = OllamaClient(streamingTransport: streamingTransport(lines: lines))

    let snapshots = try await collect(client.generateStream(prompt: "say hi"))

    #expect(snapshots == ["The ", "The cat ", "The cat sat."])
}

// Slice 4: when the model wraps its answer in a conversational preamble despite
// the prompt, generateStream cleans each cumulative snapshot so only the real
// content reaches the caller — the final snapshot has no "Sure, here's…:" wrapper
// (issue #7).
@Test func streamingGenerateStripsConversationalWrapper() async throws {
    let lines = [
        #"{"response":"Sure, here's the corrected text:\n\n","done":false}"#,
        #"{"response":"The cat sat.","done":true}"#,
    ]
    let client = OllamaClient(streamingTransport: streamingTransport(lines: lines))

    let snapshots = try await collect(client.generateStream(prompt: "fix this"))

    #expect(snapshots.last == "The cat sat.")
}
