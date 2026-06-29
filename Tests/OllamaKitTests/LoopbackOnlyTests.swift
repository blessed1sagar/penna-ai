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

// Lets the test capture the request the client tried to send.
// @unchecked Sendable: only read after generate() returns, single-threaded.
private final class HostRecorder: @unchecked Sendable {
    var host: String?
}

// Regression for #27: the default baseURL must use the IPv4 loopback 127.0.0.1,
// NOT the `localhost` name. macOS resolves `localhost` to IPv6 `::1` first, but a
// default Ollama install binds 127.0.0.1 only — so a `localhost` default makes a
// doomed `::1` attempt that adds latency and can time out. We assert the host the
// request actually targets via the transport seam (NOT passing a baseURL, so the
// default is exercised), so no live server is needed.
@Test func defaultBaseURLUsesIPv4Loopback() async throws {
    let recorder = HostRecorder()
    let client = OllamaClient(transport: { request in
        recorder.host = request.url?.host
        let body = Data(#"{"response":"ok"}"#.utf8)
        let http = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        return (body, http)
    })

    _ = try await client.generate(prompt: "hi")
    #expect(recorder.host == "127.0.0.1")
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
