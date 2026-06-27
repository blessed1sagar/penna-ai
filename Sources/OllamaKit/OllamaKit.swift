import Foundation

/// A "way to fetch": given a request, hand back the data and the HTTP response.
/// Real code uses URLSession; tests pass a fake that returns a canned body.
/// This is the seam that makes the client testable without a live server.
/// `@Sendable` so the client can be used from an actor (e.g. the main-actor Panel)
/// across the async boundary without data-race warnings.
public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

/// The streaming counterpart to `Transport`: given a request, hand back the
/// response head plus an async stream of the body's **lines** (one NDJSON object
/// per line). Real code wraps `URLSession.bytes(for:)` + `bytes.lines`; tests
/// pass a fake that emits canned NDJSON lines one at a time — the seam that lets
/// us prove progressive, line-by-line delivery without a live server.
/// `@Sendable` for the same actor-crossing reason as `Transport`.
public typealias StreamingTransport = @Sendable (URLRequest) async throws -> (AsyncThrowingStream<String, Error>, URLResponse)

/// Errors the client can surface to its caller.
public enum OllamaError: Error, Equatable {
    /// Ollama replied with a non-2xx HTTP status (e.g. 404 = model not installed).
    case httpStatus(Int)
    /// The caller asked to process empty or whitespace-only text.
    case emptyInput
    /// Could not reach the Ollama server (e.g. it isn't running).
    case unreachable
}

/// Talks to a local Ollama server's /api/generate endpoint.
/// `Sendable` (all members are): callable from any actor, including the Panel.
public struct OllamaClient: Sendable {
    private let baseURL: URL
    private let model: String
    private let transport: Transport
    private let streamingTransport: StreamingTransport

    public init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        model: String = "qwen2.5:7b-instruct-q4_K_M",
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) },
        streamingTransport: @escaping StreamingTransport = OllamaClient.defaultStreamingTransport
    ) {
        self.baseURL = baseURL
        self.model = model
        self.transport = transport
        self.streamingTransport = streamingTransport
    }

    /// The real streaming transport: opens a byte stream with URLSession and
    /// re-publishes it as the body's lines, so the client decodes NDJSON
    /// line-by-line. (Tests replace this with a fake that emits canned lines.)
    public static let defaultStreamingTransport: StreamingTransport = { request in
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let lines = AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return (lines, response)
    }

    /// Sends one prompt and returns the model's completed text.
    /// Pass `temperature` to control randomness (0 = deterministic); omit it to
    /// let Ollama use its default.
    public func generate(prompt: String, temperature: Double? = nil) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GenerateRequest(
                model: model,
                prompt: prompt,
                stream: false,
                options: temperature.map { GenerateRequest.Options(temperature: $0) }
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(request)
        } catch is URLError {
            // A connection-level failure (e.g. Ollama not running) — surface it as
            // a clear, caller-friendly error instead of leaking the raw URLError.
            throw OllamaError.unreachable
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw OllamaError.httpStatus(http.statusCode)
        }

        // stream:false means the body is a SINGLE JSON object, so we decode one
        // value — not a stream of newline-delimited objects.
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return decoded.response
    }

    /// Streams a prompt's completion: returns a stream of CUMULATIVE text
    /// snapshots — each value is the full text generated so far — so a caller
    /// (e.g. the Panel) can show output progressively as the model produces it.
    /// The body is NDJSON: one JSON object per line, each with a partial
    /// `response`, the final line carrying `done:true`. We decode each line and
    /// accumulate the `response` fields — we do NOT parse the whole body as one
    /// JSON document (implementation-notes.md: the most common streaming bug).
    public func generateStream(prompt: String, temperature: Double? = nil) -> AsyncThrowingStream<String, Error> {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try? JSONEncoder().encode(
            GenerateRequest(
                model: model,
                prompt: prompt,
                stream: true,
                options: temperature.map { GenerateRequest.Options(temperature: $0) }
            )
        )
        request.httpBody = body

        let streamingTransport = self.streamingTransport
        let sendableRequest = request
        return AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    let lines: AsyncThrowingStream<String, Error>
                    let response: URLResponse
                    do {
                        (lines, response) = try await streamingTransport(sendableRequest)
                    } catch is URLError {
                        throw OllamaError.unreachable
                    }

                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        throw OllamaError.httpStatus(http.statusCode)
                    }

                    var accumulated = ""
                    for try await line in lines {
                        // Skip blank keep-alive lines; decode each NDJSON object on its own.
                        guard !line.isEmpty else { continue }
                        let chunk = try JSONDecoder().decode(StreamChunk.self, from: Data(line.utf8))
                        accumulated += chunk.response
                        continuation.yield(accumulated)
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The JSON body we POST to /api/generate. stream:false asks Ollama for one
/// complete object instead of a newline-delimited stream of fragments.
private struct GenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
    /// Per-request model knobs (e.g. temperature). Omitted from the JSON when nil
    /// — Swift's synthesized Encodable skips nil optionals.
    let options: Options?

    struct Options: Encodable {
        let temperature: Double
    }
}

/// The shape of a non-streaming /api/generate reply (only the field we need).
private struct GenerateResponse: Decodable {
    let response: String
}

/// One NDJSON line from a streaming /api/generate reply: a partial `response`
/// fragment plus a `done` flag that is true on the final line.
private struct StreamChunk: Decodable {
    let response: String
    let done: Bool
}
