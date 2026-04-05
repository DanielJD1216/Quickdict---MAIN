import SwiftUI

struct DashboardView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var appStatus = AppStatusCenter.shared
    @State private var ollamaAvailable = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                hotkeyStatusSection
                quickActionsSection
                featuresSection
                statusSection
                ollamaSection
            }
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            checkOllama()
        }
    }

    private var hotkeyStatusSection: some View {
        HStack {
            Image(systemName: appStatus.hotkeyReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(appStatus.hotkeyReady ? .green : .orange)
            Text("Global Hotkey: \(appStatus.hotkeyMessage)")
                .font(.subheadline)
                .foregroundColor(appStatus.hotkeyReady ? .primary : .orange)
            Spacer()
            Button("Check Permissions") {
                checkAccessibility()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func checkAccessibility() {
        NotificationCenter.default.post(name: Notification.Name("quickdict.checkPermissions"), object: nil)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quickdict")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Local-First Voice Dictation for macOS")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 16) {
                QuickActionCard(
                    title: appStatus.dictationState == .recording ? "Stop Dictation" : "Start Dictation",
                    subtitle: appStatus.dictationState == .recording ? "Stop and transcribe current take" : (appStatus.asrReady ? "Hold Right Option or click to dictate" : appStatus.asrMessage),
                    icon: "mic.fill",
                    color: .blue,
                    isActive: appStatus.dictationState == DictationLifecycleState.recording
                ) {
                    startDictation()
                }

                QuickActionCard(
                    title: "Transform Text",
                    subtitle: "Select text and dictate command",
                    icon: "text.badge.checkmark",
                    color: .purple,
                    isActive: false
                ) {
                    settings.transformSelectedText.toggle()
                }
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Text Processing")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureToggleCard(
                    title: "Filler Words",
                    subtitle: "Remove um, uh, like, etc.",
                    isOn: $settings.removeFillers,
                    icon: "text.bubble"
                )

                FeatureToggleCard(
                    title: "False Starts",
                    subtitle: "Remove self-corrections",
                    isOn: $settings.removeFalseStarts,
                    icon: "arrow.uturn.backward"
                )

                FeatureToggleCard(
                    title: "Number Conversion",
                    subtitle: "Convert spoken numbers to digits",
                    isOn: $settings.numberConversion,
                    icon: "number"
                )

                FeatureToggleCard(
                    title: "Auto-Punctuation",
                    subtitle: "Insert periods and commas",
                    isOn: $settings.autoPunctuation,
                    icon: "textformat"
                )

                FeatureToggleCard(
                    title: "Bullet Points",
                    subtitle: "Format bullet commands",
                    isOn: $settings.bulletPoints,
                    icon: "list.bullet"
                )

                FeatureToggleCard(
                    title: "Transform Mode",
                    subtitle: "Voice commands for selected text",
                    isOn: $settings.transformSelectedText,
                    icon: "wand.and.stars"
                )
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Status")
                .font(.headline)

            HStack(spacing: 24) {
                StatusCard(
                    title: "Microphone",
                    value: appStatus.microphoneLabel,
                    icon: "mic.fill",
                    status: .good
                )

                StatusCard(
                    title: "ASR Model",
                    value: appStatus.asrMessage,
                    icon: "brain",
                    status: appStatus.asrReady ? .good : .warning
                )

                StatusCard(
                    title: "Language",
                    value: "Auto-detect",
                    icon: "globe",
                    status: .good
                )

                StatusCard(
                    title: "Hotkey",
                    value: "Right Option",
                    icon: "keyboard",
                    status: appStatus.hotkeyReady ? .good : .warning
                )
            }

            StatusCard(
                title: "Dictation State",
                value: appStatus.dictationState.title,
                icon: "waveform",
                status: statusLevel(for: appStatus.dictationState)
            )
        }
    }

    private var ollamaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transform with Ollama")
                    .font(.headline)
                Spacer()
                if ollamaAvailable {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Label("Not Connected", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }

            if !ollamaAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Install Ollama to enable transform mode:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Group {
                        Text("1. brew install ollama")
                            .font(.system(.caption, design: .monospaced))
                        Text("2. ollama pull qwen2.5:2b")
                            .font(.system(.caption, design: .monospaced))
                        Text("3. ollama serve")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            } else {
                Text("Ollama is running with qwen2.5:2b model")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func startDictation() {
        if appStatus.dictationState == .recording {
            NotificationCenter.default.post(name: Notification.Name("quickdict.stopDictation"), object: nil)
        } else {
            NotificationCenter.default.post(name: Notification.Name("quickdict.startDictation"), object: nil)
        }
    }

    private func checkOllama() {
        Task {
            ollamaAvailable = OllamaClient.isAvailable()
        }
    }

    private func statusLevel(for state: DictationLifecycleState) -> StatusCard.StatusLevel {
        switch state {
        case .idle, .done:
            return .good
        case .recording, .processing:
            return .warning
        case .error:
            return .bad
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isActive ? color : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isActive ? .white : .primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isActive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 300)
    }
}

struct FeatureToggleCard: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isOn ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let status: StatusLevel

    enum StatusLevel {
        case good, warning, bad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .bad: return .red
        }
    }

    private var statusText: String {
        switch status {
        case .good: return "Ready"
        case .warning: return "Check"
        case .bad: return "Error"
        }
    }
}
