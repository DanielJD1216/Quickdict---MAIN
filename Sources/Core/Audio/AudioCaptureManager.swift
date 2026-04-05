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
    private let asrEngine = ASREngine.shared
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)
    private var detectedSpeech = false
    private var rawSampleRate: Double = 0

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
        rawSampleRate = 0
        vad = VoiceActivityDetector()

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            delegate?.audioCapture(self, didEncounterError: AudioCaptureError.engineInitFailed)
            return
        }

        inputNode = engine.inputNode
        let format = inputNode!.outputFormat(forBus: 0)
        rawSampleRate = format.sampleRate

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
        let finalRawBuffer = audioBuffer
        bufferLock.unlock()

        let finalRawLevel = rms(finalRawBuffer)

        print("[AudioCapture] Recording stopped with \(finalRawBuffer.count) raw samples at \(Int(rawSampleRate))Hz")

        if finalRawLevel < 0.001 {
            delegate?.audioCapture(self, didEncounterError: AudioCaptureError.noAudioDetected)
            return
        }

        guard let convertedBuffer = convertSessionToTargetSamples(finalRawBuffer), !convertedBuffer.isEmpty else {
            delegate?.audioCapture(self, didEncounterError: AudioCaptureError.transcriptionFailed)
            return
        }

        let finalConvertedLevel = rms(convertedBuffer)

        Task { @MainActor in
            AppStatusCenter.shared.setAudioDiagnostics(rawInputSampleRate: self.rawSampleRate, rawAudioLevel: finalRawLevel, inputSampleRate: self.sampleRate, capturedSamples: convertedBuffer.count, audioLevel: finalConvertedLevel, speechDetected: self.detectedSpeech)
        }

        print("[AudioCapture] Recording stopped, processing \(convertedBuffer.count) converted samples...")

        Task {
            await transcribe(buffer: convertedBuffer)
        }
    }

    func stop() {
        stopRecording()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let rawSamples = extractMonoFloatSamples(from: buffer) else { return }

        let rawLevel = rms(rawSamples)

        if let vad = vad {
            let isSpeech = vad.detect(samples: rawSamples)
            if isSpeech {
                detectedSpeech = true
                delegate?.audioCapture(self, didDetectSpeech: true)
            }
        }

        bufferLock.lock()
        audioBuffer.append(contentsOf: rawSamples)
        let totalRawSamples = audioBuffer.count
        bufferLock.unlock()

        let estimatedConvertedSamples = rawSampleRate > 0 ? Int(Double(totalRawSamples) * (sampleRate / rawSampleRate)) : 0

        Task { @MainActor in
            AppStatusCenter.shared.setAudioDiagnostics(rawInputSampleRate: buffer.format.sampleRate, rawAudioLevel: rawLevel, inputSampleRate: self.sampleRate, capturedSamples: estimatedConvertedSamples, audioLevel: rawLevel, speechDetected: self.detectedSpeech)
        }

        delegate?.audioCapture(self, didCaptureBuffer: buffer)
    }

    private func transcribe(buffer: [Float]) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("[AudioCapture] Sending \(buffer.count) resampled samples to ASR")

        do {
            let text = try await asrEngine.transcribe(samples: buffer, sampleRate: Int(sampleRate))
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

    private func convertSessionToTargetSamples(_ rawSamples: [Float]) -> [Float]? {
        guard let targetFormat else { return nil }
        guard rawSampleRate > 0 else { return nil }

        let sourceFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rawSampleRate, channels: 1, interleaved: false)
        guard let sourceFormat else { return nil }
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(rawSamples.count)) else { return nil }

        sourceBuffer.frameLength = AVAudioFrameCount(rawSamples.count)
        guard let sourceChannel = sourceBuffer.floatChannelData?[0] else { return nil }
        rawSamples.withUnsafeBufferPointer { pointer in
            sourceChannel.assign(from: pointer.baseAddress!, count: rawSamples.count)
        }

        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let estimatedFrames = AVAudioFrameCount((Double(rawSamples.count) * ratio).rounded(.up)) + 64
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedFrames) else { return nil }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else { return nil }

        var error: NSError?
        var didProvideInput = false
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .endOfStream
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let error {
            print("[AudioCapture] Session conversion error: \(error)")
            return nil
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return extractFloatSamples(from: outputBuffer)
        case .error:
            print("[AudioCapture] Session converter returned error status")
            return nil
        @unknown default:
            return nil
        }
    }

    private func extractMonoFloatSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return [] }

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channelData = buffer.floatChannelData else { return nil }
            return downmixToMono(channelCount: Int(buffer.format.channelCount), frameLength: frameLength) { channel, index in
                channelData[channel][index]
            }
        case .pcmFormatInt16:
            guard let channelData = buffer.int16ChannelData else { return nil }
            return downmixToMono(channelCount: Int(buffer.format.channelCount), frameLength: frameLength) { channel, index in
                Float(channelData[channel][index]) / Float(Int16.max)
            }
        case .pcmFormatInt32:
            guard let channelData = buffer.int32ChannelData else { return nil }
            return downmixToMono(channelCount: Int(buffer.format.channelCount), frameLength: frameLength) { channel, index in
                Float(channelData[channel][index]) / Float(Int32.max)
            }
        default:
            return nil
        }
    }

    private func downmixToMono(channelCount: Int, frameLength: Int, sampleAt: (Int, Int) -> Float) -> [Float] {
        let safeChannelCount = max(1, channelCount)
        var mono = [Float](repeating: 0, count: frameLength)
        for frame in 0..<frameLength {
            var sum: Float = 0
            for channel in 0..<safeChannelCount {
                sum += sampleAt(channel, frame)
            }
            mono[frame] = sum / Float(safeChannelCount)
        }
        return mono
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
