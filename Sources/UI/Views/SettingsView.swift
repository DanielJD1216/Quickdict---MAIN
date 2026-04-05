import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                triggerSection
                audioSection
                processingSection
                outputSection
                aboutSection
            }
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Configure Quickdict to your preferences")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var triggerSection: some View {
        SettingsSection(title: "Trigger Key", icon: "keyboard") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activation Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.triggerKey) {
                    ForEach(TriggerKeyOption.allCases, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                .pickerStyle(.segmented)

                Text("Hold the trigger key to record. Release to transcribe.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var audioSection: some View {
        SettingsSection(title: "Audio", icon: "mic") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Microphone")
                        .font(.subheadline)
                    Spacer()
                    Button("Refresh") {
                        // Refresh microphones
                    }
                    .buttonStyle(.borderless)
                }

                Picker("", selection: $settings.selectedMicrophoneID) {
                    Text("System Default").tag(0)
                }
                .pickerStyle(.menu)

                Text("Select the microphone to use for dictation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var processingSection: some View {
        SettingsSection(title: "Text Processing", icon: "text.badge.checkmark") {
            VStack(alignment: .leading, spacing: 16) {
                SettingsToggle(
                    title: "Remove filler words",
                    subtitle: "Strip um, uh, like, etc.",
                    isOn: $settings.removeFillers
                )

                SettingsToggle(
                    title: "Remove false starts",
                    subtitle: "Detect and remove self-corrections",
                    isOn: $settings.removeFalseStarts
                )

                SettingsToggle(
                    title: "Number conversion",
                    subtitle: "Convert spoken numbers to digits",
                    isOn: $settings.numberConversion
                )

                SettingsToggle(
                    title: "Auto-punctuation",
                    subtitle: "Insert periods and commas automatically",
                    isOn: $settings.autoPunctuation
                )

                SettingsToggle(
                    title: "Bullet points",
                    subtitle: "Format bullet commands as bullet lists",
                    isOn: $settings.bulletPoints
                )

                Divider()

                SettingsToggle(
                    title: "Transform selected text",
                    subtitle: "When text is selected, treat dictation as commands",
                    isOn: $settings.transformSelectedText
                )
            }
        }
    }

    private var outputSection: some View {
        SettingsSection(title: "Output", icon: "arrow.right.doc.on.clipboard") {
            VStack(alignment: .leading, spacing: 16) {
                SettingsToggle(
                    title: "Auto-paste",
                    subtitle: "Automatically paste transcribed text",
                    isOn: $settings.autoPaste
                )

                SettingsToggle(
                    title: "Copy to clipboard",
                    subtitle: "Copy transcribed text to clipboard",
                    isOn: $settings.copyToClipboard
                )

                SettingsToggle(
                    title: "Auto-send",
                    subtitle: "Press Enter after paste (dangerous!)",
                    isOn: $settings.autoSend
                )

                if settings.autoSend {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Auto-send will press Enter after pasting - be careful!")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Version")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("1.0.0")
                }

                HStack {
                    Text("Quickdict")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}
