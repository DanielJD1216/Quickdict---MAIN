import Foundation

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    @Published var triggerKey: TriggerKeyOption {
        didSet { defaults.set(triggerKey.rawValue, forKey: Keys.triggerKey) }
    }

    @Published var selectedMicrophoneID: Int {
        didSet { defaults.set(selectedMicrophoneID, forKey: Keys.microphoneID) }
    }

    @Published var selectedModel: ModelOption {
        didSet { defaults.set(selectedModel.rawValue, forKey: Keys.model) }
    }

    @Published var transcriptionLanguage: LanguageOption {
        didSet { defaults.set(transcriptionLanguage.rawValue, forKey: Keys.language) }
    }

    @Published var removeFillers: Bool {
        didSet { defaults.set(removeFillers, forKey: Keys.removeFillers) }
    }

    @Published var removeFalseStarts: Bool {
        didSet { defaults.set(removeFalseStarts, forKey: Keys.removeFalseStarts) }
    }

    @Published var numberConversion: Bool {
        didSet { defaults.set(numberConversion, forKey: Keys.numberConversion) }
    }

    @Published var autoPunctuation: Bool {
        didSet { defaults.set(autoPunctuation, forKey: Keys.autoPunctuation) }
    }

    @Published var bulletPoints: Bool {
        didSet { defaults.set(bulletPoints, forKey: Keys.bulletPoints) }
    }

    @Published var transformSelectedText: Bool {
        didSet { defaults.set(transformSelectedText, forKey: Keys.transformSelected) }
    }

    @Published var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) }
    }

    @Published var copyToClipboard: Bool {
        didSet { defaults.set(copyToClipboard, forKey: Keys.copyClipboard) }
    }

    @Published var autoSend: Bool {
        didSet { defaults.set(autoSend, forKey: Keys.autoSend) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private init() {
        self.triggerKey = TriggerKeyOption(rawValue: defaults.string(forKey: Keys.triggerKey) ?? "") ?? .rightOption
        self.selectedMicrophoneID = defaults.integer(forKey: Keys.microphoneID)
        self.selectedModel = ModelOption(rawValue: defaults.string(forKey: Keys.model) ?? "") ?? .parakeetV3
        self.transcriptionLanguage = LanguageOption(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .autoDetect
        self.removeFillers = defaults.object(forKey: Keys.removeFillers) as? Bool ?? true
        self.removeFalseStarts = defaults.object(forKey: Keys.removeFalseStarts) as? Bool ?? true
        self.numberConversion = defaults.object(forKey: Keys.numberConversion) as? Bool ?? true
        self.autoPunctuation = defaults.object(forKey: Keys.autoPunctuation) as? Bool ?? false
        self.bulletPoints = defaults.object(forKey: Keys.bulletPoints) as? Bool ?? true
        self.transformSelectedText = defaults.object(forKey: Keys.transformSelected) as? Bool ?? true
        self.autoPaste = defaults.object(forKey: Keys.autoPaste) as? Bool ?? true
        self.copyToClipboard = defaults.object(forKey: Keys.copyClipboard) as? Bool ?? true
        self.autoSend = defaults.object(forKey: Keys.autoSend) as? Bool ?? false
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    private enum Keys {
        static let triggerKey = "triggerKey"
        static let microphoneID = "microphoneID"
        static let model = "model"
        static let language = "language"
        static let removeFillers = "removeFillers"
        static let removeFalseStarts = "removeFalseStarts"
        static let numberConversion = "numberConversion"
        static let autoPunctuation = "autoPunctuation"
        static let bulletPoints = "bulletPoints"
        static let transformSelected = "transformSelected"
        static let autoPaste = "autoPaste"
        static let copyClipboard = "copyToClipboard"
        static let autoSend = "autoSend"
        static let launchAtLogin = "launchAtLogin"
    }
}

enum TriggerKeyOption: String, CaseIterable {
    case rightOption = "right_option"
    case fnGlobe = "fn_globe"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .rightOption: return "Right Option (default)"
        case .fnGlobe: return "FN / Globe"
        case .custom: return "Custom..."
        }
    }
}

enum ModelOption: String, CaseIterable {
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
        case .parakeetV3: return "Best accuracy • ~700 MB"
        case .qwen3ASR: return "30 languages • ~1.7 GB"
        }
    }
}

enum LanguageOption: String, CaseIterable {
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
