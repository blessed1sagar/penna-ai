import Foundation

/// A "way to fetch": given a request, hand back the data and the HTTP response.
/// Real code uses URLSession; tests pass a fake that returns a canned body.
/// This is the seam that makes the client testable without a live server.
/// `@Sendable` so the client can be used from an actor (e.g. the main-actor Panel)
/// across the async boundary without data-race warnings.
public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

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

    public init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        model: String = "qwen2.5:7b-instruct-q4_K_M",
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.baseURL = baseURL
        self.model = model
        self.transport = transport
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
