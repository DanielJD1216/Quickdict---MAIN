import SwiftUI
import FluidAudio

struct ModelManagementView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var appStatus = AppStatusCenter.shared
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadMessage = ""
    @State private var installedTransformModels = Set<String>()
    @State private var transformDownloadInProgressFor: String?
    @State private var transformDownloadMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                modelsSection
                transformModelsSection
                Spacer()
            }
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: refreshTransformModels)
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

            if !downloadMessage.isEmpty {
                Text(downloadMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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
                    needsPreferredVariantUpgrade: needsPreferredVariantUpgrade(for: model),
                    isDownloading: isDownloading,
                    downloadProgress: downloadProgress,
                    onSelect: { settings.selectedModel = model },
                    onDownload: { startDownload(for: model) }
                )
            }
        }
    }

    private var transformModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transform Models")
                .font(.headline)

            Text("Via Ollama")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !transformDownloadMessage.isEmpty {
                Text(transformDownloadMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(OllamaClient.supportedModels) { model in
                TransformModelCard(
                    model: model,
                    isInstalled: installedTransformModels.contains(model.name),
                    isSelected: settings.selectedTransformModel == model.name,
                    isInstalling: transformDownloadInProgressFor == model.name,
                    onSelect: {
                        settings.selectedTransformModel = model.name
                        transformDownloadMessage = "Selected \(model.title) for text transforms."
                    },
                    onInstall: { installTransformModel(model) }
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
            if #available(macOS 15, *) {
                let int8Installed = Qwen3AsrModels.modelsExist(at: Qwen3AsrModels.defaultCacheDirectory(variant: .int8))
                let f32Installed = Qwen3AsrModels.modelsExist(at: Qwen3AsrModels.defaultCacheDirectory(variant: .f32))
                return int8Installed || f32Installed
            }
            return false
        }
    }

    private func needsPreferredVariantUpgrade(for model: ModelOption) -> Bool {
        guard model == .qwen3ASR else { return false }
        guard #available(macOS 15, *) else { return false }

        let int8Installed = Qwen3AsrModels.modelsExist(at: Qwen3AsrModels.defaultCacheDirectory(variant: .int8))
        let f32Installed = Qwen3AsrModels.modelsExist(at: Qwen3AsrModels.defaultCacheDirectory(variant: .f32))
        return f32Installed && !int8Installed
    }

    private func startDownload(for model: ModelOption) {
        guard model == .qwen3ASR else { return }

        guard #available(macOS 15, *) else {
            downloadMessage = "Qwen3 ASR download requires macOS 15 or later."
            return
        }

        isDownloading = true
        downloadProgress = 0

        Task {
            do {
                downloadMessage = "Downloading Qwen3 ASR from Hugging Face..."
                _ = try await Qwen3AsrModels.download(variant: .int8) { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress.fractionCompleted
                        self.downloadMessage = "\(progress.phase): \(Int(progress.fractionCompleted * 100))%"
                    }
                }

                await MainActor.run {
                    self.isDownloading = false
                    self.downloadProgress = 1.0
                    self.settings.selectedModel = .qwen3ASR
                    self.downloadMessage = "Qwen3 ASR downloaded successfully."
                }
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadMessage = "Qwen3 download failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func refreshTransformModels() {
        installedTransformModels = OllamaClient.installedModelNames()
    }

    private func installTransformModel(_ model: OllamaTransformModel) {
        transformDownloadInProgressFor = model.name
        transformDownloadMessage = "Installing \(model.title) via Ollama..."

        Task {
            do {
                try await OllamaClient.pullModel(named: model.name)
                await MainActor.run {
                    self.transformDownloadInProgressFor = nil
                    self.settings.selectedTransformModel = model.name
                    self.refreshTransformModels()
                    self.transformDownloadMessage = "Installed \(model.title)."
                }
            } catch {
                await MainActor.run {
                    self.transformDownloadInProgressFor = nil
                    self.transformDownloadMessage = error.localizedDescription
                }
            }
        }
    }
}

struct ModelCard: View {
    let model: ModelOption
    let isSelected: Bool
    let isInstalled: Bool
    let needsPreferredVariantUpgrade: Bool
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

                    if model == .qwen3ASR, let variantLabel = qwenVariantLabel, isInstalled {
                        Text(variantLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isInstalled && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                } else if isInstalled {
                    Button("Select") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
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

            if isDownloading && model == .qwen3ASR {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: downloadProgress)
                    Text("Downloading... \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if model == .qwen3ASR && needsPreferredVariantUpgrade && !isDownloading {
                HStack {
                    Label("Faster int8 variant recommended", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Install Faster int8 Variant") {
                        onDownload()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: 16) {
                InfoBadge(icon: "memorychip", text: memoryLabel)
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

private extension ModelCard {
    var qwenVariantLabel: String? {
        guard model == .qwen3ASR else { return nil }
        guard #available(macOS 15, *) else { return nil }

        if Qwen3AsrModels.modelsExist(at: Qwen3AsrModels.defaultCacheDirectory(variant: .int8)) {
            return "Installed variant: int8"
        }
        if Qwen3AsrModels.modelsExist(at: Qwen3AsrModels.defaultCacheDirectory(variant: .f32)) {
            return "Installed variant: f32"
        }
        return nil
    }

    var memoryLabel: String {
        switch model {
        case .parakeetV3:
            return "~700 MB"
        case .qwen3ASR:
            if let variantLabel = qwenVariantLabel {
                return variantLabel.contains("int8") ? "~900 MB" : "~1.7 GB"
            }
            return "~900 MB int8"
        }
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

struct TransformModelCard: View {
    let model: OllamaTransformModel
    let isInstalled: Bool
    let isSelected: Bool
    let isInstalling: Bool
    let onSelect: () -> Void
    let onInstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.title)
                            .font(.headline)
                        if isSelected {
                            Label("Selected", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    Text(model.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                } else if isInstalled {
                    Button("Select") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSelected)
                } else {
                    Button("Download") {
                        onInstall()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: 16) {
                InfoBadge(icon: "shippingbox", text: model.sizeLabel)
                InfoBadge(icon: "cpu", text: "Ollama")
                InfoBadge(icon: "wand.and.stars", text: "Transform")
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
