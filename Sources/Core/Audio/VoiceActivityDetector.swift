import Foundation
import Accelerate

final class VoiceActivityDetector {
    private var energyHistory: [Float] = []
    private let historySize = 10
    private var isSpeaking = false

    private let energyThreshold: Float = 0.02
    private let speechConfirmFrames = 3
    private var consecutiveSpeechFrames = 0
    private let silenceConfirmFrames = 5
    private var consecutiveSilenceFrames = 0

    func detect(samples: [Float]) -> Bool {
        let energy = calculateEnergy(samples: samples)

        energyHistory.append(energy)
        if energyHistory.count > historySize {
            energyHistory.removeFirst()
        }

        let avgEnergy = energyHistory.reduce(0, +) / Float(energyHistory.count)
        let dynamicThreshold = max(energyThreshold, avgEnergy * 0.5)

        if energy > dynamicThreshold {
            consecutiveSpeechFrames += 1
            consecutiveSilenceFrames = 0

            if consecutiveSpeechFrames >= speechConfirmFrames && !isSpeaking {
                isSpeaking = true
                return true
            }
        } else {
            consecutiveSilenceFrames += 1
            consecutiveSpeechFrames = 0

            if consecutiveSilenceFrames >= silenceConfirmFrames && isSpeaking {
                isSpeaking = false
                return false
            }
        }

        return isSpeaking
    }

    private func calculateEnergy(samples: [Float]) -> Float {
        var sum: Float = 0
        vDSP_measqv(samples, 1, &sum, vDSP_Length(samples.count))
        return sqrt(sum / Float(samples.count))
    }

    func reset() {
        energyHistory.removeAll()
        isSpeaking = false
        consecutiveSpeechFrames = 0
        consecutiveSilenceFrames = 0
    }
}
