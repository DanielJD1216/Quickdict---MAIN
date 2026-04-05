import Foundation
import FluidAudio

actor ASREngine {
    private var isReady = false
    private var asrManager: AsrManager?
    private let minimumSampleCount = 16_000

    static func modelSearchPaths() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml", isDirectory: true),
            home.appendingPathComponent("parakeet-tdt-0.6b-v3-coreml", isDirectory: true)
        ]
    }

    static func installedModelURL() -> URL? {
        modelSearchPaths().first(where: { modelsExist(at: $0) })
    }

    static func modelIsInstalled() -> Bool {
        installedModelURL() != nil
    }

    static func statusMessage() -> String {
        if let url = installedModelURL() {
            return "Parakeet v3 ready"
        }
        return "No Parakeet v3 model found"
    }

    static func validateAvailability() async -> (Bool, String) {
        guard installedModelURL() != nil else {
            return (false, statusMessage())
        }

        let engine = ASREngine()
        do {
            try await engine.load()
            return (true, "Parakeet v3 ready")
        } catch {
            return (false, "Parakeet v3 failed to load: \(error.localizedDescription)")
        }
    }

    private static func modelsExist(at url: URL) -> Bool {
        let required = [
            "Preprocessor.mlmodelc",
            "Encoder.mlmodelc",
            "Decoder.mlmodelc",
            "JointDecision.mlmodelc",
            "parakeet_vocab.json"
        ]

        return required.allSatisfy { name in
            FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path)
        }
    }

    func load() async throws {
        guard let modelURL = Self.installedModelURL() else {
            throw ASRError.modelNotLoaded
        }

        let models = try await AsrModels.load(from: modelURL, version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        asrManager = manager
        isReady = true

        print("[ASR] Loaded Parakeet v3 from \(modelURL.path)")
    }

    func transcribe(samples: [Float], sampleRate: Int) async throws -> String {
        if !isReady {
            try await load()
        }

        guard let asrManager else {
            throw ASRError.modelNotLoaded
        }

        guard !samples.isEmpty else {
            throw ASRError.emptyAudio
        }

        var normalizedSamples = samples
        if normalizedSamples.count < minimumSampleCount {
            normalizedSamples.append(contentsOf: Array(repeating: 0, count: minimumSampleCount - normalizedSamples.count))
        }

        let result = try await asrManager.transcribe(normalizedSamples)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            throw ASRError.emptyTranscription
        }

        return text
    }
}

enum ASRError: Error, LocalizedError {
    case modelNotLoaded
    case inputBufferCreationFailed
    case invalidModelArchitecture
    case predictionFailed
    case invalidOutput
    case emptyTranscription
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Parakeet v3 was not found or could not be loaded."
        case .inputBufferCreationFailed:
            return "Failed to create input buffer"
        case .invalidModelArchitecture:
            return "Invalid model architecture"
        case .predictionFailed:
            return "Model prediction failed"
        case .invalidOutput:
            return "Invalid model output"
        case .emptyTranscription:
            return "No speech was transcribed. Check microphone input level and audio format."
        case .emptyAudio:
            return "No audio was captured. Check microphone permission and input source."
        }
    }
}
