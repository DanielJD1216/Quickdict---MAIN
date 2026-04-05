import Foundation

protocol LLMClient {
    func transform(text: String, command: String) async throws -> String
}

final class OllamaClient: LLMClient {
    private let baseURL = URL(string: "http://localhost:11434")!
    private let model = "qwen2.5:2b"

    func transform(text: String, command: String) async throws -> String {
        let prompt = """
        You are a text transformation assistant.

        Original text:
        \(text)

        Command: \(command)

        Transform the text according to the command. Return ONLY the transformed text, nothing else.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 500
            ]
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.requestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw LLMError.invalidResponse
        }

        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isAvailable() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var available = false

        URLSession.shared.dataTask(with: URL(string: "http://localhost:11434/api/tags")!) { data, response, _ in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                available = true
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 2)
        return available
    }
}

final class CloudLLMClient: LLMClient {
    private var apiKey: String
    private var endpoint: URL

    init(apiKey: String, endpoint: URL) {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    func transform(text: String, command: String) async throws -> String {
        throw LLMError.notImplemented
    }
}

enum LLMError: Error, LocalizedError {
    case notAvailable
    case notImplemented
    case requestFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Ollama is not running. Please install Ollama and pull qwen2.5:2b"
        case .notImplemented:
            return "Cloud LLM not implemented yet"
        case .requestFailed:
            return "Failed to connect to LLM service"
        case .invalidResponse:
            return "Invalid response from LLM service"
        }
    }
}

final class TransformManager {
    static let shared = TransformManager()

    private var client: LLMClient?

    private init() {
        setupClient()
    }

    private func setupClient() {
        if OllamaClient.isAvailable() {
            client = OllamaClient()
            print("[Transform] Using Ollama (qwen2.5:2b)")
        } else {
            print("[Transform] Ollama not available - transform disabled")
        }
    }

    func transform(text: String, command: String) async throws -> String {
        guard let client = client else {
            throw LLMError.notAvailable
        }

        return try await client.transform(text: text, command: command)
    }
}
