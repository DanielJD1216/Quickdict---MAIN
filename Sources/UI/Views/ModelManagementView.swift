import SwiftUI

struct ModelManagementView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var appStatus = AppStatusCenter.shared
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                modelsSection
                Spacer()
            }
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Choose and manage ASR models for transcription")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(appStatus.asrMessage)
                .font(.callout)
                .foregroundColor(appStatus.asrReady ? .green : .orange)
                .padding(.top, 4)

            Button("Refresh Model Status") {
                refreshModelStatus()
            }
            .buttonStyle(.bordered)
        }
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ASR Models")
                .font(.headline)

            ForEach(ModelOption.allCases, id: \.self) { model in
                ModelCard(
                    model: model,
                    isSelected: settings.selectedModel == model,
                    isInstalled: installed(for: model),
                    isDownloading: isDownloading,
                    downloadProgress: downloadProgress,
                    onSelect: { settings.selectedModel = model },
                    onDownload: { startDownload() }
                )
            }
        }
    }

    private func refreshModelStatus() {
        appStatus.setASR(ready: ASREngine.modelIsInstalled(), message: ASREngine.statusMessage())
    }

    private func installed(for model: ModelOption) -> Bool {
        switch model {
        case .parakeetV3:
            return ASREngine.modelIsInstalled()
        case .qwen3ASR:
            return false
        }
    }

    private func startDownload() {
        isDownloading = true
        downloadProgress = 0

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.02
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
            }
        }
    }
}

struct ModelCard: View {
    let model: ModelOption
    let isSelected: Bool
    let isInstalled: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)

                        if isSelected && isInstalled {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if isSelected {
                            Label("Selected", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isInstalled && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                } else if model == .qwen3ASR {
                    Button("Download") {
                        onDownload()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Select") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if isDownloading && isSelected {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: downloadProgress)
                    Text("Downloading... \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                InfoBadge(icon: "memorychip", text: model == .parakeetV3 ? "~700 MB" : "~1.7 GB")
                InfoBadge(icon: "cpu", text: "Apple Neural Engine")
                InfoBadge(icon: "globe", text: model == .parakeetV3 ? "English" : "30 Languages")
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct InfoBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(4)
    }
}
