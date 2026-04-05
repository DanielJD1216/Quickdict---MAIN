import AppKit
import ApplicationServices

struct DictationTargetContext {
    let applicationBundleIdentifier: String?
    let selectedText: String?
}

final class OutputManager {
    static let shared = OutputManager()

    private init() {}

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("[Output] Copied to clipboard: \(text.prefix(50))...")
    }

    func pasteToActiveApp(_ text: String) {
        copyToClipboard(text)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        print("[Output] Simulated Cmd+V paste")
    }

    func sendEnter() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let source = CGEventSource(stateID: .hidSystemState)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            print("[Output] Simulated Enter key")
        }
    }

    func getSelectedText() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard focusedResult == .success,
              let focusedElementRef else {
            return nil
        }
        let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement.self)

        var selectedTextValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        if result == .success, let text = selectedTextValue as? String, !text.isEmpty {
            return text
        }

        return nil
    }

    func captureSelectedTextWithFallback() -> String? {
        if let text = getSelectedText(), !text.isEmpty {
            return text
        }

        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        simulateCopy()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        let copiedString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        if let previousString {
            pasteboard.setString(previousString, forType: .string)
        }

        guard let copiedString, !copiedString.isEmpty, copiedString != previousString else {
            return nil
        }

        return copiedString
    }

    func output(text: String, settings: SettingsManager) {
        output(text: text, settings: settings, target: nil)
    }

    func output(text: String, settings: SettingsManager, target: DictationTargetContext?) {
        restoreTargetApplication(target)

        if settings.copyToClipboard {
            copyToClipboard(text)
        }

        if settings.autoPaste {
            pasteToActiveApp(text)

            if settings.autoSend {
                sendEnter()
            }
        }
    }

    func captureTargetContext(includeSelectedText: Bool) -> DictationTargetContext {
        let app = NSWorkspace.shared.frontmostApplication
        let selectedText = includeSelectedText ? captureSelectedTextWithFallback() : nil
        let summary = selectedText.map { "captured \($0.count) chars" } ?? "no selection captured"
        Task { @MainActor in
            AppStatusCenter.shared.setTransformDebug("Target app: \(app?.bundleIdentifier ?? "unknown"), \(summary)")
        }
        return DictationTargetContext(
            applicationBundleIdentifier: app?.bundleIdentifier,
            selectedText: selectedText
        )
    }

    private func restoreTargetApplication(_ target: DictationTargetContext?) {
        guard let bundleIdentifier = target?.applicationBundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return
        }

        app.activate(options: [.activateIgnoringOtherApps])
    }

    private func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
