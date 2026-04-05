import SwiftUI

struct SettingsWindow: View {
    var body: some View {
        TabView {
            TriggerSettingsView()
                .tabItem { Label("Trigger", systemImage: "keyboard") }
                .tag(0)

            AudioSettingsView()
                .tabItem { Label("Audio", systemImage: "mic") }
                .tag(1)

            ModelSettingsView()
                .tabItem { Label("Model", systemImage: "brain") }
                .tag(2)

            LanguageSettingsView()
                .tabItem { Label("Language", systemImage: "globe") }
                .tag(3)

            ProcessingSettingsView()
                .tabItem { Label("Processing", systemImage: "text.badge.checkmark") }
                .tag(4)

            OutputSettingsView()
                .tabItem { Label("Output", systemImage: "arrow.right.doc.on.clipboard") }
                .tag(5)
        }
        .frame(minWidth: 450, minHeight: 500)
        .padding()
    }
}

struct TriggerSettingsView: View {
    @State private var selectedTrigger: TriggerKeyOption = .rightOption
    @State private var isRecording = false

    var body: some View {
        Form {
            Section {
                Picker("Trigger Key", selection: $selectedTrigger) {
                    ForEach(TriggerKeyOption.allCases, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                .pickerStyle(.menu)

                Text("Hold the trigger key to record. Release to transcribe.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Lock mode (press Space while holding trigger)", isOn: .constant(true))
                    .toggleStyle(.switch)

                Text("While holding trigger, press Space to lock recording for longer takes. Press trigger again to stop.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .navigationTitle("Trigger Settings")
    }
}

struct AudioSettingsView: View {
    @State private var devices: [AudioDeviceInfo] = [AudioDeviceInfo(id: 0, name: "System Default", isDefault: true)]
    @State private var selectedDevice: AudioDeviceInfo?

    var body: some View {
        Form {
            Section {
                Picker("Microphone", selection: $selectedDevice) {
                    ForEach(devices, id: \.id) { device in
                        Text(device.name).tag(device as AudioDeviceInfo?)
                    }
                }
                .pickerStyle(.menu)

                Button("Refresh Microphones") {
                    refreshDevices()
                }

                if let device = selectedDevice {
                    Text("Active input: \(device.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("Audio Settings")
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

        if selectedDevice == nil && !devices.isEmpty {
            selectedDevice = devices.first
        }
    }
}

struct AudioDeviceInfo: Identifiable, Hashable {
    let id: Int
    let name: String
    let isDefault: Bool
}

struct ModelSettingsView: View {
    @State private var selectedModel: ModelType = .parakeetV3
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

    var body: some View {
        Form {
            Section {
                ForEach(ModelType.allCases, id: \.self) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                                .fontWeight(model == selectedModel ? .semibold : .regular)
                            Text(model.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if model == selectedModel {
                            Text("Selected")
                                .foregroundColor(.green)
                        } else {
                            Button("Select") {
                                selectedModel = model
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                if isDownloading {
                    ProgressView(value: downloadProgress)
                    Text("Downloading... \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Cancel") {
                        isDownloading = false
                    }
                } else {
                    Button("Download \(selectedModel == .qwen3ASR ? "Qwen3" : "Parakeet v3")") {
                        startDownload()
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Model Settings")
    }

    private func startDownload() {
        isDownloading = true
        downloadProgress = 0

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.05
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
            }
        }
    }
}

enum ModelType: String, CaseIterable {
    case parakeetV3 = "parakeet_v3"
    case qwen3ASR = "qwen3_asr"

    var displayName: String {
        switch self {
        case .parakeetV3: return "Parakeet v3"
        case .qwen3ASR: return "Qwen3 ASR"
        }
    }

    var description: String {
        switch self {
        case .parakeetV3: return "Best accuracy • ~700 MB • Apple Neural Engine"
        case .qwen3ASR: return "30 languages • ~1.7 GB • Apple Neural Engine"
        }
    }
}

struct LanguageSettingsView: View {
    @State private var selectedLanguage: TranscriptionLanguage = .autoDetect

    var body: some View {
        Form {
            Section {
                Picker("Transcription Language", selection: $selectedLanguage) {
                    ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)

                Text("Auto-detect automatically identifies the spoken language. Manual selection uses the selected language regardless of actual speech.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .navigationTitle("Language Settings")
    }
}

enum TranscriptionLanguage: String, CaseIterable {
    case autoDetect = "auto"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case portuguese = "pt"
    case italian = "it"

    var displayName: String {
        switch self {
        case .autoDetect: return "Auto-detect"
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .portuguese: return "Portuguese"
        case .italian: return "Italian"
        }
    }
}

struct ProcessingSettingsView: View {
    @State private var removeFillers = true
    @State private var removeFalseStarts = true
    @State private var numberConversion = true
    @State private var autoPunctuation = false
    @State private var bulletPoints = true
    @State private var transformSelected = true
    @State private var ollamaAvailable = false

    var body: some View {
        Form {
            Section(header: Text("Text Processing")) {
                ToggleRow(title: "Remove filler words", subtitle: "Strip 'um', 'uh', 'like', etc.", isOn: $removeFillers)
                ToggleRow(title: "Remove false starts", subtitle: "Detect and remove self-corrections", isOn: $removeFalseStarts)
                ToggleRow(title: "Number conversion (ITN)", subtitle: "Convert spoken numbers to digits", isOn: $numberConversion)
                ToggleRow(title: "Auto-punctuation", subtitle: "Insert periods and commas automatically", isOn: $autoPunctuation)
                ToggleRow(title: "Bullet points", subtitle: "Format 'bullet' commands as bullet lists", isOn: $bulletPoints)
            }

            Section(header: Text("Transform Mode (Requires Ollama)")) {
                ToggleRow(title: "Transform selected text", subtitle: "When text is selected, treat dictation as commands", isOn: $transformSelected)

                if ollamaAvailable {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Ollama is ready with qwen2.5:2b")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Ollama not detected")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }

                        Text("Transform mode requires Ollama to be installed.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Group {
                            Text("1. Install Ollama:")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("brew install ollama")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("2. Pull the model:")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("ollama pull qwen2.5:2b")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("3. Start Ollama:")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("ollama serve")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }

                Text("Example commands: 'rewrite more formally', 'reformat as bullets', 'make it shorter'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .navigationTitle("Processing Settings")
        .onAppear {
            checkOllama()
        }
    }

    private func checkOllama() {
        Task {
            ollamaAvailable = OllamaChecker.isAvailable()
        }
    }
}

struct OllamaChecker {
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

struct OutputSettingsView: View {
    @State private var autoPaste = true
    @State private var copyToClipboard = true
    @State private var autoSend = false

    var body: some View {
        Form {
            Section {
                Toggle("Auto-paste", isOn: $autoPaste)
                    .toggleStyle(.switch)

                Toggle("Copy to clipboard", isOn: $copyToClipboard)
                    .toggleStyle(.switch)

                Toggle("Auto-send (press Enter after paste)", isOn: $autoSend)
                    .toggleStyle(.switch)

                Text("Auto-send is dangerous if enabled accidentally - text will be pasted AND sent immediately.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .navigationTitle("Output Settings")
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
    }
}
