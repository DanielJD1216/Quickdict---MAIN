import Foundation
import SwiftUI

enum DictationLifecycleState: Equatable {
    case idle
    case recording
    case processing
    case done
    case error(String)

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .done:
            return "Done"
        case .error:
            return "Error"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "Ready when dependencies are available"
        case .recording:
            return "Listening to microphone input"
        case .processing:
            return "Running transcription pipeline"
        case .done:
            return "Last request completed"
        case .error(let message):
            return message
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .recording:
            return .red
        case .processing:
            return .orange
        case .done:
            return .green
        case .error:
            return .red
        }
    }
}

final class AppStatusCenter: ObservableObject {
    static let shared = AppStatusCenter()

    @Published var dictationState: DictationLifecycleState = .idle
    @Published var lastTranscript = ""
    @Published var hotkeyReady = false
    @Published var hotkeyMessage = "Not registered"
    @Published var accessibilityGranted = false
    @Published var microphoneLabel = "System Default"
    @Published var asrReady = false
    @Published var asrMessage = "No ASR model installed"
    @Published var outputMessage = "No output yet"
    @Published var rawInputSampleRate: Double = 0
    @Published var rawAudioLevel: Float = 0
    @Published var inputSampleRate: Double = 0
    @Published var capturedSamples = 0
    @Published var capturedDurationSeconds: Double = 0
    @Published var audioLevel: Float = 0
    @Published var speechDetected = false
    @Published var lastAsrLatency: Double = 0

    private init() {}

    var canStartDictation: Bool {
        hotkeyReady && asrReady
    }

    func setHotkey(ready: Bool, message: String) {
        hotkeyReady = ready
        hotkeyMessage = message
    }

    func setAccessibility(granted: Bool) {
        accessibilityGranted = granted
    }

    func setASR(ready: Bool, message: String) {
        asrReady = ready
        asrMessage = message
    }

    func setOutputMessage(_ message: String) {
        outputMessage = message
    }

    func setAudioDiagnostics(rawInputSampleRate: Double, rawAudioLevel: Float, inputSampleRate: Double, capturedSamples: Int, audioLevel: Float, speechDetected: Bool) {
        self.rawInputSampleRate = rawInputSampleRate
        self.rawAudioLevel = rawAudioLevel
        self.inputSampleRate = inputSampleRate
        self.capturedSamples = capturedSamples
        self.capturedDurationSeconds = inputSampleRate > 0 ? Double(capturedSamples) / inputSampleRate : 0
        self.audioLevel = audioLevel
        self.speechDetected = speechDetected
    }

    func setAsrLatency(_ latency: Double) {
        lastAsrLatency = latency
    }
}
