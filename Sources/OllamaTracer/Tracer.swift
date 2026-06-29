import Foundation
import OllamaKit

// A throwaway command-line tracer: proves OllamaKit can talk to the REAL local
// Ollama and get genuine model output, before we wire it into the macOS app.
@main
struct Tracer {
    static func main() async {
        // Default OllamaClient() -> real URLSession + the v1 model on 127.0.0.1:11434.
        let client = OllamaClient()
        let prompt = "Correct the grammar and reply with only the corrected sentence: "
            + "\"me and him goes to the store yesterday\""

        print("→ Sending one prompt to Ollama (qwen2.5:7b-instruct-q4_K_M)…")
        do {
            let text = try await client.generate(prompt: prompt)
            print("← Model replied:\n\(text)")
        } catch {
            print("✗ Error talking to Ollama: \(error)")
        }

        // Verify the Improve-mode brain end-to-end against the real model.
        let messy = "me and him goes to the store yesterday"
        print("\n→ Improve mode — input: \(messy)")
        do {
            let corrected = try await client.improve(text: messy)
            print("← Improved:\n\(corrected)")
        } catch {
            print("✗ Improve failed: \(error)")
        }
    }
}
