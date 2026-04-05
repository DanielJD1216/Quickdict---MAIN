import SwiftUI

struct DictationView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var appStatus = AppStatusCenter.shared
    @State private var showRecordingIndicator = false

    private var isRecording: Bool {
        appStatus.dictationState == DictationLifecycleState.recording
    }

    var body: some View {
        VStack(spacing: 32) {
            headerSection
            recordingSection
            transcriptSection
            controlsSection
            timedTestSection
            diagnosticsSection
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dictation")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Hold the trigger key to start recording, release to transcribe")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(appStatus.dictationState.detail)
                .font(.caption)
                .foregroundColor(appStatus.dictationState.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recordingSection: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(isRecording ? Color.red.opacity(0.4) : Color.gray.opacity(0.2))
                    .frame(width: 150, height: 150)

                Circle()
                    .fill(isRecording ? Color.red : Color.gray)
                    .frame(width: 100, height: 100)

                if isRecording {
                    Circle()
                        .stroke(Color.red, lineWidth: 3)
                        .frame(width: 200, height: 200)
                        .scaleEffect(showRecordingIndicator ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: showRecordingIndicator)
                }

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .onTapGesture {
                toggleRecording()
            }

            Text(labelText)
                .font(.headline)
                .foregroundColor(isRecording ? .red : .secondary)
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()
                if !appStatus.lastTranscript.isEmpty {
                    Button(action: copyTranscript) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            ScrollView {
                Text(appStatus.lastTranscript.isEmpty ? "Your transcribed text or error will appear here..." : appStatus.lastTranscript)
                    .font(.body)
                    .foregroundColor(appStatus.lastTranscript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(minHeight: 150)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Microphone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    MicrophonePicker()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trigger Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TriggerKeyPicker()
                }
            }

            HStack(spacing: 16) {
                Toggle("Auto-paste", isOn: $settings.autoPaste)
                    .toggleStyle(.switch)
                Toggle("Copy to clipboard", isOn: $settings.copyToClipboard)
                    .toggleStyle(.switch)
                Toggle("Auto-send", isOn: $settings.autoSend)
                    .toggleStyle(.switch)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var timedTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Isolation Test")
                .font(.headline)

            Text("Runs a 3-second recording without using the hold-to-record trigger. Use this to verify whether audio capture and transcription work independently of the hotkey.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Run 3-Second Dictation Test") {
                NotificationCenter.default.post(name: Notification.Name("quickdict.runTimedTestDictation"), object: nil)
            }
            .buttonStyle(.borderedProminent)
            .disabled(appStatus.dictationState == .recording)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics")
                .font(.headline)

            HStack(spacing: 24) {
                diagnosticItem(title: "Mic", value: settings.selectedMicrophoneID == 0 ? "System Default" : "Custom")
                diagnosticItem(title: "Raw Rate", value: appStatus.rawInputSampleRate > 0 ? "\(Int(appStatus.rawInputSampleRate)) Hz" : "Unknown")
                diagnosticItem(title: "Raw Level", value: String(format: "%.3f", appStatus.rawAudioLevel))
                diagnosticItem(title: "Input Rate", value: appStatus.inputSampleRate > 0 ? "\(Int(appStatus.inputSampleRate)) Hz" : "Unknown")
                diagnosticItem(title: "Captured", value: "\(appStatus.capturedSamples) samples")
                diagnosticItem(title: "Duration", value: String(format: "%.2fs", appStatus.capturedDurationSeconds))
                diagnosticItem(title: "Level", value: String(format: "%.3f", appStatus.audioLevel))
                diagnosticItem(title: "Speech", value: appStatus.speechDetected ? "Detected" : "No")
                diagnosticItem(title: "ASR", value: appStatus.asrReady ? "Ready" : "Not ready")
                diagnosticItem(title: "Latency", value: appStatus.lastAsrLatency > 0 ? String(format: "%.2fs", appStatus.lastAsrLatency) : "-")
            }

            Text(appStatus.outputMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            if !appStatus.transformDebug.isEmpty {
                Text("Transform: \(appStatus.transformDebug)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func diagnosticItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        showRecordingIndicator = true
        NotificationCenter.default.post(name: Notification.Name("quickdict.startDictation"), object: nil)
    }

    private func stopRecording() {
        showRecordingIndicator = false
        NotificationCenter.default.post(name: Notification.Name("quickdict.stopDictation"), object: nil)
    }

    private func copyTranscript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appStatus.lastTranscript, forType: .string)
    }

    private var labelText: String {
        switch appStatus.dictationState {
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .done:
            return "Done"
        case .error:
            return "Error"
        case .idle:
            return appStatus.asrReady ? "Click to start" : "ASR model required"
        }
    }
}

struct MicrophonePicker: View {
    @State private var devices: [AudioDeviceInfo] = []
    @State private var selectedDevice: AudioDeviceInfo?

    var body: some View {
        Picker("", selection: $selectedDevice) {
            ForEach(devices, id: \.id) { device in
                Text(device.name).tag(device as AudioDeviceInfo?)
            }
        }
        .pickerStyle(.menu)
        .onAppear {
            refreshDevices()
        }
    }

    private func refreshDevices() {
        devices = [AudioDeviceInfo(id: 0, name: "System Default", isDefault: true)]
        let systemDevices = AudioCaptureManager.listAudioDevices()
        for device in systemDevices where device.hasInput {
            devices.append(AudioDeviceInfo(id: Int(device.id), name: device.name, isDefault: false))
        }
        if selectedDevice == nil {
            selectedDevice = devices.first
        }
    }
}

struct TriggerKeyPicker: View {
    @State private var selectedTrigger: TriggerKeyOption = .rightOption

    var body: some View {
        Picker("", selection: $selectedTrigger) {
            ForEach(TriggerKeyOption.allCases, id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.menu)
    }
}
