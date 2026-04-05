import Foundation
import FluidAudio

actor ASREngine {
    static let shared = ASREngine()

    private var isReady = false
    private var loadedModel: ModelOption?
    private var parakeetManager: AsrManager?
    private var qwenBackend: Any?
    private let minimumSampleCount = 16_000
    private let qwenMaxNewTokens = 160

    static func modelIsInstalled(_ model: ModelOption = SettingsManager.shared.selectedModel) -> Bool {
        switch model {
        case .parakeetV3:
            return installedParakeetModelURL() != nil
        case .qwen3ASR:
            return installedQwenModelURL() != nil
        }
    }

    static func statusMessage(_ model: ModelOption = SettingsManager.shared.selectedModel) -> String {
        switch model {
        case .parakeetV3:
            return installedParakeetModelURL() != nil ? "Parakeet v3 ready" : "No Parakeet v3 model found"
        case .qwen3ASR:
            guard #available(macOS 15, *) else {
                return "Qwen3 ASR requires macOS 15 or later"
            }
            return installedQwenModelURL() != nil ? "Qwen3 ASR ready" : "No Qwen3 ASR model found"
        }
    }

    static func validateAvailability(_ model: ModelOption = SettingsManager.shared.selectedModel) async -> (Bool, String) {
        do {
            try await ASREngine.shared.load(for: model)
            return (true, statusMessage(model))
        } catch {
            return (false, error.localizedDescription)
        }
    }

    func load(for model: ModelOption = SettingsManager.shared.selectedModel) async throws {
        if isReady, loadedModel == model {
            return
        }

        if model == .parakeetV3, parakeetManager != nil {
            loadedModel = model
            isReady = true
            return
        }

        if model == .qwen3ASR, qwenBackend != nil {
            loadedModel = model
            isReady = true
            return
        }

        isReady = false
        loadedModel = nil

        switch model {
        case .parakeetV3:
            guard let modelURL = Self.installedParakeetModelURL() else {
                throw ASRError.modelNotLoaded("Parakeet v3 was not found or could not be loaded.")
            }

            let models = try await AsrModels.load(from: modelURL, version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            parakeetManager = manager
            print("[ASR] Loaded Parakeet v3 from \(modelURL.path)")

        case .qwen3ASR:
            guard #available(macOS 15, *) else {
                throw ASRError.modelNotLoaded("Qwen3 ASR requires macOS 15 or later.")
            }
            guard let (modelURL, variant) = Self.installedQwenModelLocation() else {
                throw ASRError.modelNotLoaded("Qwen3 ASR was not found or could not be loaded.")
            }

            let manager = Qwen3AsrManager()
            try await manager.loadModels(from: modelURL)
            qwenBackend = manager
            print("[ASR] Loaded Qwen3 ASR (\(variant.rawValue)) from \(modelURL.path)")
        }

        loadedModel = model
        isReady = true
    }

    func transcribe(samples: [Float], sampleRate: Int) async throws -> String {
        let selectedModel = SettingsManager.shared.selectedModel
        if !isReady || loadedModel != selectedModel {
            try await load(for: selectedModel)
        }

        guard !samples.isEmpty else {
            throw ASRError.emptyAudio
        }

        var normalizedSamples = samples
        if normalizedSamples.count < minimumSampleCount {
            normalizedSamples.append(contentsOf: Array(repeating: 0, count: minimumSampleCount - normalizedSamples.count))
        }

        let text: String
        switch selectedModel {
        case .parakeetV3:
            guard let parakeetManager else {
                throw ASRError.modelNotLoaded("Parakeet v3 manager is not loaded.")
            }
            let result = try await parakeetManager.transcribe(normalizedSamples)
            text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        case .qwen3ASR:
            guard #available(macOS 15, *) else {
                throw ASRError.modelNotLoaded("Qwen3 ASR requires macOS 15 or later.")
            }
            guard let qwenManager = qwenBackend as? Qwen3AsrManager else {
                throw ASRError.modelNotLoaded("Qwen3 ASR manager is not loaded.")
            }

            let language = qwenLanguageHint(from: SettingsManager.shared.transcriptionLanguage)
            text = try await qwenManager.transcribe(audioSamples: normalizedSamples, language: language, maxNewTokens: qwenMaxNewTokens)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if text.isEmpty {
            throw ASRError.emptyTranscription
        }

        return text
    }

    private func qwenLanguageHint(from language: LanguageOption) -> String? {
        language == .autoDetect ? nil : language.rawValue
    }

    private static func installedParakeetModelURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml", isDirectory: true),
            home.appendingPathComponent("parakeet-tdt-0.6b-v3-coreml", isDirectory: true)
        ]

        return candidates.first(where: { parakeetModelsExist(at: $0) })
    }

    private static func installedQwenModelURL() -> URL? {
        installedQwenModelLocation()?.directory
    }

    private static func installedQwenModelLocation() -> (directory: URL, variant: Qwen3AsrVariant)? {
        guard #available(macOS 15, *) else { return nil }

        let preferredVariants: [Qwen3AsrVariant] = [.int8, .f32]
        for variant in preferredVariants {
            let directory = Qwen3AsrModels.defaultCacheDirectory(variant: variant)
            if Qwen3AsrModels.modelsExist(at: directory) {
                return (directory, variant)
            }
        }

        return nil
    }

    private static func parakeetModelsExist(at url: URL) -> Bool {
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
}

enum ASRError: Error, LocalizedError {
    case modelNotLoaded(String)
    case inputBufferCreationFailed
    case invalidModelArchitecture
    case predictionFailed
    case invalidOutput
    case emptyTranscription
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded(let message):
            return message
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
