import AppKit
import ApplicationServices

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
        guard let focusedElement = AXUIElementCreateSystemWide() as AXUIElement? else {
            return nil
        }

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

    func output(text: String, settings: SettingsManager) {
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
}
