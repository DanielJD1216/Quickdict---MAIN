import Foundation
import AVFoundation
import CoreAudio
import Accelerate

protocol AudioCaptureDelegate: AnyObject {
    func audioCapture(_ manager: AudioCaptureManager, didCaptureBuffer buffer: AVAudioPCMBuffer)
    func audioCapture(_ manager: AudioCaptureManager, didDetectSpeech start: Bool)
    func audioCapture(_ manager: AudioCaptureManager, didFinishWithText text: String)
    func audioCapture(_ manager: AudioCaptureManager, didEncounterError error: Error)
}

final class AudioCaptureManager: NSObject {
    static let shared = AudioCaptureManager()

    weak var delegate: AudioCaptureDelegate?

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    private var isRecording = false
    private var vad: VoiceActivityDetector?
    private var asrEngine: ASREngine?
    private var audioConverter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)
    private var detectedSpeech = false

    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 512

    var currentDeviceID: AudioDeviceID?

    private override init() {
        super.init()
    }

    func startRecording() {
        guard !isRecording else { return }

        audioBuffer.removeAll()
        detectedSpeech = false
        vad = VoiceActivityDetector()
        asrEngine = ASREngine()

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            delegate?.audioCapture(self, didEncounterError: AudioCaptureError.engineInitFailed)
            return
        }

        inputNode = engine.inputNode
        let format = inputNode!.outputFormat(forBus: 0)
        audioConverter = AVAudioConverter(from: format, to: targetFormat!)

        print("[AudioCapture] Input format: \(format)")
        print("[AudioCapture] Sample rate: \(format.sampleRate), channels: \(format.channelCount)")

        Task { @MainActor in
            AppStatusCenter.shared.setAudioDiagnostics(rawInputSampleRate: format.sampleRate, rawAudioLevel: 0, inputSampleRate: self.sampleRate, capturedSamples: 0, audioLevel: 0, speechDetected: false)
        }

        inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        do {
            try engine.start()
            isRecording = true
            print("[AudioCapture] Recording started")
        } catch {
            print("[AudioCapture] Engine start error: \(error)")
            delegate?.audioCapture(self, didEncounterError: error)
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false

        bufferLock.lock()
        let finalBuffer = audioBuffer
        bufferLock.unlock()

        let finalLevel = rms(finalBuffer)

        Task { @MainActor in
            AppStatusCenter.shared.setAudioDiagnostics(rawInputSampleRate: AppStatusCenter.shared.rawInputSampleRate, rawAudioLevel: AppStatusCenter.shared.rawAudioLevel, inputSampleRate: self.sampleRate, capturedSamples: finalBuffer.count, audioLevel: finalLevel, speechDetected: self.detectedSpeech)
        }

        print("[AudioCapture] Recording stopped, processing \(finalBuffer.count) samples...")

        if finalLevel < 0.001 {
            delegate?.audioCapture(self, didEncounterError: AudioCaptureError.noAudioDetected)
            return
        }

        Task {
            await transcribe(buffer: finalBuffer)
        }
    }

    func stop() {
        stopRecording()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let rawLevel = rms(from: buffer)
        guard let samples = convertToTargetSamples(buffer) else { return }

        let level = rms(samples)

        if let vad = vad {
            let isSpeech = vad.detect(samples: samples)
            if isSpeech {
                detectedSpeech = true
                delegate?.audioCapture(self, didDetectSpeech: true)
            }
        }

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        let totalSamples = audioBuffer.count
        bufferLock.unlock()

        Task { @MainActor in
            AppStatusCenter.shared.setAudioDiagnostics(rawInputSampleRate: buffer.format.sampleRate, rawAudioLevel: rawLevel, inputSampleRate: self.sampleRate, capturedSamples: totalSamples, audioLevel: level, speechDetected: self.detectedSpeech)
        }

        delegate?.audioCapture(self, didCaptureBuffer: buffer)
    }

    private func transcribe(buffer: [Float]) async {
        guard let engine = asrEngine else { return }

        let startTime = CFAbsoluteTimeGetCurrent()
        print("[AudioCapture] Sending \(buffer.count) resampled samples to ASR")

        do {
            let text = try await engine.transcribe(samples: buffer, sampleRate: Int(sampleRate))
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            print("[AudioCapture] Transcription complete in \(String(format: "%.3f", latency))s: \"\(text)\"")

            await MainActor.run {
                AppStatusCenter.shared.setAsrLatency(latency)
                self.delegate?.audioCapture(self, didFinishWithText: text)
            }
        } catch {
            print("[AudioCapture] Transcription error: \(error)")
            await MainActor.run {
                self.delegate?.audioCapture(self, didEncounterError: error)
            }
        }
    }

    private func convertToTargetSamples(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let targetFormat else { return nil }
        guard let converter = audioConverter else {
            return extractFloatSamples(from: buffer)
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let estimatedFrames = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedFrames) else {
            return nil
        }

        var error: NSError?
        var didProvideInput = false

        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .endOfStream
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            print("[AudioCapture] Conversion error: \(error)")
            return nil
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            break
        case .error:
            print("[AudioCapture] Converter returned error status")
            return nil
        @unknown default:
            return nil
        }

        return extractFloatSamples(from: outputBuffer)
    }

    private func extractFloatSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
    }

    private func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var meanSquare: Float = 0
        vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(samples.count))
        return sqrt(meanSquare)
    }

    private func rms(from buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channelData = buffer.floatChannelData else { return 0 }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            return rms(samples)
        case .pcmFormatInt16:
            guard let channelData = buffer.int16ChannelData else { return 0 }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength)).map { Float($0) / Float(Int16.max) }
            return rms(samples)
        case .pcmFormatInt32:
            guard let channelData = buffer.int32ChannelData else { return 0 }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength)).map { Float($0) / Float(Int32.max) }
            return rms(samples)
        default:
            return 0
        }
    }

    static func listAudioDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else { return [] }

        return deviceIDs.compactMap { id -> AudioDevice? in
            var nameProperty = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)

            status = AudioObjectGetPropertyData(id, &nameProperty, 0, nil, &nameSize, &name)

            guard status == noErr else { return nil }

            var hasInput = false
            var inputProperty = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var inputSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(id, &inputProperty, 0, nil, &inputSize)
            if status == noErr && inputSize > 0 {
                hasInput = true
            }

            return AudioDevice(id: id, name: name as String, hasInput: hasInput)
        }
    }
}

struct AudioDevice {
    let id: AudioDeviceID
    let name: String
    let hasInput: Bool
}

enum AudioCaptureError: Error {
    case engineInitFailed
    case noInputAvailable
    case transcriptionFailed
    case recordingTooShort
    case noAudioDetected
}

extension AudioCaptureError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .engineInitFailed:
            return "Audio engine failed to initialize."
        case .noInputAvailable:
            return "No microphone input is available."
        case .transcriptionFailed:
            return "Transcription failed."
        case .recordingTooShort:
            return "Recording ended before enough audio was captured."
        case .noAudioDetected:
            return "No audible microphone input was detected. Check the selected microphone and input level."
        }
    }
}

extension AudioCaptureManager: AudioCaptureDelegate {
    func audioCapture(_ manager: AudioCaptureManager, didCaptureBuffer buffer: AVAudioPCMBuffer) {}
    func audioCapture(_ manager: AudioCaptureManager, didDetectSpeech start: Bool) {}
    func audioCapture(_ manager: AudioCaptureManager, didFinishWithText text: String) {}
    func audioCapture(_ manager: AudioCaptureManager, didEncounterError error: Error) {}
}
