import Foundation
import AppKit
import Carbon
import ApplicationServices

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onTriggerPressed: (() -> Void)?
    var onTriggerReleased: (() -> Void)?
    var isLockMode = false
    var isSpacePressed = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRecording = false
    private(set) var isHotkeyReady = false
    private(set) var statusMessage = "Not registered"
    private var triggerPressedAt: CFAbsoluteTime = 0
    private var releaseVerificationWorkItem: DispatchWorkItem?

    private var keyCode: CGKeyCode = CGKeyCode(kVK_RightOption)
    private var modifiers: CGEventFlags = .maskAlternate
    private var mode: TriggerConfiguration.Mode = .modifierOnly

    private init() {}

    func register(trigger: TriggerConfiguration) {
        unregister()

        keyCode = CGKeyCode(trigger.keyCode)
        modifiers = cgFlags(from: trigger.modifiers)
        mode = trigger.mode

        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
            isHotkeyReady = false
            statusMessage = "Input Monitoring permission required"
            Task { @MainActor in
                AppStatusCenter.shared.setHotkey(ready: false, message: self.statusMessage)
            }
            print("[Hotkey] Listen-event access not granted")
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = manager.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                    manager.statusMessage = "Ready"
                    manager.isHotkeyReady = true
                    Task { @MainActor in
                        AppStatusCenter.shared.setHotkey(ready: true, message: manager.statusMessage)
                    }
                }
                return Unmanaged.passUnretained(event)
            }

            let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = manager.normalized(event.flags)

            switch manager.mode {
            case .modifierOnly:
                manager.handleModifierOnlyEvent(type: type, keyCode: eventKeyCode, flags: flags)
            case .keyCombo:
                manager.handleKeyComboEvent(type: type, keyCode: eventKeyCode, flags: flags)
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: refcon
        )

        guard let eventTap else {
            isHotkeyReady = false
            statusMessage = "Failed to create event tap"
            Task { @MainActor in
                AppStatusCenter.shared.setHotkey(ready: false, message: self.statusMessage)
            }
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        isHotkeyReady = true
        statusMessage = "Ready: \(trigger.displayName)"
        Task { @MainActor in
            AppStatusCenter.shared.setHotkey(ready: true, message: self.statusMessage)
        }
        print("[Hotkey] Registered trigger: \(trigger.displayName)")
    }

    func unregister() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        releaseVerificationWorkItem?.cancel()
        releaseVerificationWorkItem = nil
        isHotkeyReady = false
        statusMessage = "Not registered"
        Task { @MainActor in
            AppStatusCenter.shared.setHotkey(ready: false, message: self.statusMessage)
        }
    }

    func stopRecording() {
        isRecording = false
        isSpacePressed = false
        triggerPressedAt = 0
        releaseVerificationWorkItem?.cancel()
        releaseVerificationWorkItem = nil
    }

    private func handleModifierOnlyEvent(type: CGEventType, keyCode eventKeyCode: CGKeyCode, flags: CGEventFlags) {
        guard eventKeyCode == keyCode else { return }
        let isTriggerPressed = triggerIsPressed(in: flags)

        if type == .flagsChanged && isTriggerPressed && !isRecording {
            beginRecordingTrigger()
        } else if type == .flagsChanged && !isTriggerPressed && isRecording {
            let heldDuration = CFAbsoluteTimeGetCurrent() - triggerPressedAt
            scheduleReleaseVerification(heldDuration: heldDuration)
        }
    }

    private func handleKeyComboEvent(type: CGEventType, keyCode eventKeyCode: CGKeyCode, flags: CGEventFlags) {
        let requiredFlags = normalized(modifiers)
        let matchesKey = eventKeyCode == keyCode
        let matchesModifiers = flags.contains(requiredFlags)

        if type == .keyDown && matchesKey && matchesModifiers && !isRecording {
            beginRecordingTrigger()
        } else if type == .keyUp && matchesKey && isRecording {
            finishRecordingTrigger()
        }
    }

    private func beginRecordingTrigger() {
        isRecording = true
        triggerPressedAt = CFAbsoluteTimeGetCurrent()
        releaseVerificationWorkItem?.cancel()
        releaseVerificationWorkItem = nil
        DispatchQueue.main.async {
            self.onTriggerPressed?()
        }
    }

    private func finishRecordingTrigger() {
        isRecording = false
        DispatchQueue.main.async {
            self.onTriggerReleased?()
        }
    }

    private func triggerIsPressed(in flags: CGEventFlags) -> Bool {
        switch modifiers {
        case .maskAlternate:
            return flags.contains(.maskAlternate)
        case .maskSecondaryFn:
            return flags.contains(.maskSecondaryFn)
        default:
            return false
        }
    }

    private func scheduleReleaseVerification(heldDuration: CFAbsoluteTime) {
        releaseVerificationWorkItem?.cancel()

        let delay: TimeInterval = heldDuration < 0.25 ? 0.18 : 0.05
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isRecording else { return }

            let stillPressed = CGEventSource.keyState(.hidSystemState, key: self.keyCode)
            if stillPressed {
                return
            }

            self.finishRecordingTrigger()
        }

        releaseVerificationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cgFlags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.command) { result.insert(.maskCommand) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.function) { result.insert(.maskSecondaryFn) }
        return result
    }

    private func normalized(_ flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl, .maskSecondaryFn])
    }

    deinit {
        unregister()
    }
}
