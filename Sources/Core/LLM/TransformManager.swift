import Foundation

protocol LLMClient {
    func transform(text: String, command: String) async throws -> String
}

struct StructuredTransformDocument {
    struct Segment {
        let prefix: String
        let content: String
        let suffix: String
    }

    let segments: [Segment]

    var editableText: String {
        segments.map(\ .content).joined(separator: "\n")
    }

    func rebuild(with transformedText: String) -> String? {
        let transformedLines = transformedText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard transformedLines.count == segments.count else { return nil }

        return zip(segments, transformedLines).map { segment, newContent in
            segment.prefix + newContent.trimmingCharacters(in: .whitespacesAndNewlines) + segment.suffix
        }.joined(separator: "\n")
    }

    static func parse(_ text: String) -> StructuredTransformDocument {
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let segments = rawLines.map { line -> Segment in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return Segment(prefix: "", content: "", suffix: "")
            }

            if let range = line.range(of: #"^(\\s*(?:[-*•]|\\d+[.)])\\s+)"#, options: .regularExpression) {
                let prefix = String(line[range])
                let content = String(line[range.upperBound...])
                return Segment(prefix: prefix, content: content, suffix: "")
            }

            return Segment(prefix: "", content: line, suffix: "")
        }

        return StructuredTransformDocument(segments: segments)
    }
}

struct OllamaTransformModel: Identifiable, Hashable {
    let name: String
    let title: String
    let sizeLabel: String
    let summary: String

    var id: String { name }
}

final class OllamaClient: LLMClient {
    private let baseURL = URL(string: "http://localhost:11434")!
    private let model: String

    init(model: String) {
        self.model = model
    }

    func transform(text: String, command: String) async throws -> String {
        let document = StructuredTransformDocument.parse(text)
        let expectedLineCount = document.segments.count
        let originalEditableText = document.editableText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let transformed = try await transformViaChat(text: document.editableText, command: command)
            let cleaned = sanitizeTransformedText(transformed, command: command, expectedLineCount: expectedLineCount)
            guard !cleaned.isEmpty,
                  cleaned.trimmingCharacters(in: .whitespacesAndNewlines) != originalEditableText else {
                throw LLMError.emptyResponse
            }
            return document.rebuild(with: cleaned) ?? cleaned
        } catch LLMError.emptyResponse {
            let transformed = try await transformViaGenerate(text: document.editableText, command: command)
            let cleaned = sanitizeTransformedText(transformed, command: command, expectedLineCount: expectedLineCount)
            guard !cleaned.isEmpty,
                  cleaned.trimmingCharacters(in: .whitespacesAndNewlines) != originalEditableText else {
                throw LLMError.emptyResponse
            }
            return document.rebuild(with: cleaned) ?? cleaned
        }
    }

    private func transformViaChat(text: String, command: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": model,
            "think": false,
            "messages": [
                [
                    "role": "system",
                    "content": "You rewrite text based on the user's instruction. The command is an instruction, not content. Never repeat the command. Never output labels, explanations, or markdown. Return only the rewritten text, preserving the overall structure and tone requested by the command."
                ],
                [
                    "role": "user",
                    "content": "<command>\n\(command)\n</command>\n<content>\n\(text)\n</content>"
                ]
            ],
            "stream": false,
            "options": [
                "temperature": 0.2,
                "num_predict": 300
            ]
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.requestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let responseText = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return responseText
    }

    private func transformViaGenerate(text: String, command: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": model,
            "think": false,
            "prompt": "Rewrite the content below using the command. The command is an instruction, not part of the content. Return only the rewritten text with no labels or explanations.\n\n<command>\n\(command)\n</command>\n<content>\n\(text)\n</content>",
            "stream": false,
            "options": [
                "temperature": 0.2,
                "num_predict": 200
            ]
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.requestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw LLMError.invalidResponse
        }

        return responseText
    }

    private func sanitizeTransformedText(_ text: String, command: String, expectedLineCount: Int) -> String {
        let lines = text
            .split(omittingEmptySubsequences: false, whereSeparator: \ .isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let bannedPrefixes = [
            "command:",
            "editable content lines:",
            "content lines:",
            "<command>",
            "</command>",
            "<content>",
            "</content>",
            "return exactly one transformed line for each input line",
            "return only the transformed text",
            "return only the rewritten list",
            "original text:",
            "text:",
            "commander"
        ]

        let normalizedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let cleanedLines = lines.filter { line in
            let lower = line.lowercased()
            guard !lower.isEmpty else { return true }
            if lower == normalizedCommand {
                return false
            }
            return !bannedPrefixes.contains(where: { lower.hasPrefix($0) })
        }

        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isAvailable() -> Bool {
        !installedModelNames().isEmpty
    }

    static func availableModelName() -> String? {
        availableModelName(preferred: SettingsManager.shared.selectedTransformModel)
    }

    static func availableModelName(preferred: String?) -> String? {
        let installed = installedModelNames()
        if let preferred, installed.contains(preferred) {
            return preferred
        }

        let preferredOrder = supportedModels.map(\ .name)
        return preferredOrder.first(where: { installed.contains($0) }) ?? installed.sorted().first
    }

    static func installedModelNames() -> Set<String> {
        let semaphore = DispatchSemaphore(value: 0)
        var names = Set<String>()

        URLSession.shared.dataTask(with: URL(string: "http://localhost:11434/api/tags")!) { data, response, _ in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                names = Set(models.compactMap { $0["name"] as? String })
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 2)
        return names
    }

    static let supportedModels: [OllamaTransformModel] = [
        OllamaTransformModel(name: "qwen3.5:2b", title: "Qwen 3.5 2B", sizeLabel: "2.7 GB", summary: "Fastest transform option"),
        OllamaTransformModel(name: "qwen3.5:4b", title: "Qwen 3.5 4B", sizeLabel: "3.4 GB", summary: "Better quality, moderate speed"),
        OllamaTransformModel(name: "qwen3.5:9b", title: "Qwen 3.5 9B", sizeLabel: "6.6 GB", summary: "Highest quality, slowest local option")
    ]

    static func pullModel(named modelName: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["ollama", "pull", modelName]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown ollama pull failure"
            throw LLMError.installFailed(output)
        }
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
    case emptyResponse
    case installFailed(String)

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
        case .emptyResponse:
            return "Transform model returned an empty response"
        case .installFailed(let message):
            return "Failed to install Ollama model: \(message)"
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
        if let model = OllamaClient.availableModelName(preferred: SettingsManager.shared.selectedTransformModel) {
            client = OllamaClient(model: model)
            print("[Transform] Using Ollama (\(model))")
        } else {
            client = nil
            print("[Transform] Ollama not available - transform disabled")
        }
    }

    func transform(text: String, command: String) async throws -> String {
        setupClient()
        guard let client = client else {
            throw LLMError.notAvailable
        }

        return try await client.transform(text: text, command: command)
    }
}
