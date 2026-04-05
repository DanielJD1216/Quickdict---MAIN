import Foundation
import AppKit
import Carbon.HIToolbox

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    @Published var triggerKey: TriggerKeyOption {
        didSet { defaults.set(triggerKey.rawValue, forKey: Keys.triggerKey) }
    }

    @Published var customTriggerKeyCode: Int {
        didSet { defaults.set(customTriggerKeyCode, forKey: Keys.customTriggerKeyCode) }
    }

    @Published var customTriggerModifiers: UInt {
        didSet { defaults.set(customTriggerModifiers, forKey: Keys.customTriggerModifiers) }
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

    @Published var selectedTransformModel: String {
        didSet { defaults.set(selectedTransformModel, forKey: Keys.transformModel) }
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
        self.customTriggerKeyCode = defaults.object(forKey: Keys.customTriggerKeyCode) as? Int ?? Int(kVK_ANSI_D)
        self.customTriggerModifiers = defaults.object(forKey: Keys.customTriggerModifiers) as? UInt ?? NSEvent.ModifierFlags([.command, .option]).rawValue
        self.selectedMicrophoneID = defaults.integer(forKey: Keys.microphoneID)
        self.selectedModel = ModelOption(rawValue: defaults.string(forKey: Keys.model) ?? "") ?? .parakeetV3
        self.transcriptionLanguage = LanguageOption(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .autoDetect
        self.removeFillers = defaults.object(forKey: Keys.removeFillers) as? Bool ?? true
        self.removeFalseStarts = defaults.object(forKey: Keys.removeFalseStarts) as? Bool ?? true
        self.numberConversion = defaults.object(forKey: Keys.numberConversion) as? Bool ?? true
        self.autoPunctuation = defaults.object(forKey: Keys.autoPunctuation) as? Bool ?? false
        self.bulletPoints = defaults.object(forKey: Keys.bulletPoints) as? Bool ?? true
        self.transformSelectedText = defaults.object(forKey: Keys.transformSelected) as? Bool ?? true
        self.selectedTransformModel = defaults.string(forKey: Keys.transformModel) ?? "qwen3.5:2b"
        self.autoPaste = defaults.object(forKey: Keys.autoPaste) as? Bool ?? true
        self.copyToClipboard = defaults.object(forKey: Keys.copyClipboard) as? Bool ?? true
        self.autoSend = defaults.object(forKey: Keys.autoSend) as? Bool ?? false
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    private enum Keys {
        static let triggerKey = "triggerKey"
        static let customTriggerKeyCode = "customTriggerKeyCode"
        static let customTriggerModifiers = "customTriggerModifiers"
        static let microphoneID = "microphoneID"
        static let model = "model"
        static let language = "language"
        static let removeFillers = "removeFillers"
        static let removeFalseStarts = "removeFalseStarts"
        static let numberConversion = "numberConversion"
        static let autoPunctuation = "autoPunctuation"
        static let bulletPoints = "bulletPoints"
        static let transformSelected = "transformSelected"
        static let transformModel = "transformModel"
        static let autoPaste = "autoPaste"
        static let copyClipboard = "copyToClipboard"
        static let autoSend = "autoSend"
        static let launchAtLogin = "launchAtLogin"
    }
}

extension SettingsManager {
    var triggerConfiguration: TriggerConfiguration {
        switch triggerKey {
        case .rightOption:
            return TriggerConfiguration(
                mode: .modifierOnly,
                keyCode: Int(kVK_RightOption),
                modifiers: [.option],
                displayName: "Right Option"
            )
        case .fnGlobe:
            return TriggerConfiguration(
                mode: .modifierOnly,
                keyCode: Int(kVK_Function),
                modifiers: [.function],
                displayName: "Fn / Globe"
            )
        case .custom:
            return TriggerConfiguration(
                mode: .keyCombo,
                keyCode: customTriggerKeyCode,
                modifiers: NSEvent.ModifierFlags(rawValue: customTriggerModifiers),
                displayName: ShortcutFormatter.displayName(forKeyCode: customTriggerKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: customTriggerModifiers))
            )
        }
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

struct TriggerConfiguration: Equatable {
    enum Mode: Equatable {
        case modifierOnly
        case keyCombo
    }

    let mode: Mode
    let keyCode: Int
    let modifiers: NSEvent.ModifierFlags
    let displayName: String
}

enum ShortcutFormatter {
    static func displayName(forKeyCode keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        let modifierString = symbols(for: modifiers)
        let keyString = specialKeyName(forKeyCode: keyCode) ?? characterName(forKeyCode: keyCode)
        return modifierString.isEmpty ? keyString : "\(modifierString)\(keyString)"
    }

    static func symbols(for modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "^" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        if modifiers.contains(.function) { result += "fn " }
        return result
    }

    private static func specialKeyName(forKeyCode keyCode: Int) -> String? {
        switch keyCode {
        case Int(kVK_RightOption): return "Right Option"
        case Int(kVK_Function): return "Fn"
        case Int(kVK_Space): return "Space"
        case Int(kVK_Return): return "Return"
        case Int(kVK_Tab): return "Tab"
        case Int(kVK_Delete): return "Delete"
        case Int(kVK_Escape): return "Esc"
        default: return nil
        }
    }

    private static func characterName(forKeyCode keyCode: Int) -> String {
        if let scalar = keyCodeToASCII(keyCode) {
            return String(scalar).uppercased()
        }
        return "Key \(keyCode)"
    }

    private static func keyCodeToASCII(_ keyCode: Int) -> Character? {
        switch keyCode {
        case Int(kVK_ANSI_A): return "a"
        case Int(kVK_ANSI_B): return "b"
        case Int(kVK_ANSI_C): return "c"
        case Int(kVK_ANSI_D): return "d"
        case Int(kVK_ANSI_E): return "e"
        case Int(kVK_ANSI_F): return "f"
        case Int(kVK_ANSI_G): return "g"
        case Int(kVK_ANSI_H): return "h"
        case Int(kVK_ANSI_I): return "i"
        case Int(kVK_ANSI_J): return "j"
        case Int(kVK_ANSI_K): return "k"
        case Int(kVK_ANSI_L): return "l"
        case Int(kVK_ANSI_M): return "m"
        case Int(kVK_ANSI_N): return "n"
        case Int(kVK_ANSI_O): return "o"
        case Int(kVK_ANSI_P): return "p"
        case Int(kVK_ANSI_Q): return "q"
        case Int(kVK_ANSI_R): return "r"
        case Int(kVK_ANSI_S): return "s"
        case Int(kVK_ANSI_T): return "t"
        case Int(kVK_ANSI_U): return "u"
        case Int(kVK_ANSI_V): return "v"
        case Int(kVK_ANSI_W): return "w"
        case Int(kVK_ANSI_X): return "x"
        case Int(kVK_ANSI_Y): return "y"
        case Int(kVK_ANSI_Z): return "z"
        case Int(kVK_ANSI_0): return "0"
        case Int(kVK_ANSI_1): return "1"
        case Int(kVK_ANSI_2): return "2"
        case Int(kVK_ANSI_3): return "3"
        case Int(kVK_ANSI_4): return "4"
        case Int(kVK_ANSI_5): return "5"
        case Int(kVK_ANSI_6): return "6"
        case Int(kVK_ANSI_7): return "7"
        case Int(kVK_ANSI_8): return "8"
        case Int(kVK_ANSI_9): return "9"
        default: return nil
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
