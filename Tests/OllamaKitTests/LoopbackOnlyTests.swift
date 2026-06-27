import Testing
import Foundation
@testable import OllamaKit

// ADR-0001 guardrail ("no content leaves the machine"): the client must NEVER
// send text to a non-loopback host. This guarantee CANNOT be enforced by the
// macOS App Sandbox — its network entitlement is all-or-nothing, with no
// host-level granularity (see ADR on the sandbox / network.client) — so it is
// enforced here in code. A non-loopback baseURL must make generate() throw
// BEFORE the request reaches the transport, so the personal text never leaves.
@Test func refusesToSendToNonLoopbackHost() async throws {
    // A transport that fails the test if it is ever invoked: proves the request
    // was rejected before anything could leave the machine.
    let client = OllamaClient(
        baseURL: URL(string: "http://evil.example.com")!,
        transport: { _ in
            Issue.record("transport must not be called for a non-loopback host")
            throw OllamaError.unreachable
        }
    )

    await #expect(throws: OllamaError.nonLoopbackHost) {
        _ = try await client.generate(prompt: "secret personal text")
    }
}

// The streaming path sends the same personal text, so it needs the same guard:
// consuming the stream must throw before the streaming transport is touched.
@Test func refusesToStreamToNonLoopbackHost() async throws {
    let client = OllamaClient(
        baseURL: URL(string: "http://evil.example.com")!,
        streamingTransport: { _ in
            Issue.record("streaming transport must not be called for a non-loopback host")
            throw OllamaError.unreachable
        }
    )

    await #expect(throws: OllamaError.nonLoopbackHost) {
        for try await _ in client.generateStream(prompt: "secret personal text") {}
    }
}
