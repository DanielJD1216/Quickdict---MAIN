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
    
    private var keyCode: CGKeyCode = 0x3D // Right Option
    private var modifiers: CGEventFlags = .maskAlternate

    private init() {}

    func register(trigger: TriggerKeyOption) {
        unregister()

        switch trigger {
        case .rightOption:
            keyCode = 0x3D // kVK_RightOption
            modifiers = .maskAlternate
        case .fnGlobe:
            keyCode = 0x3F // kVK_Function
            modifiers = .maskSecondaryFn
        case .custom:
            keyCode = 0x3D
            modifiers = .maskAlternate
        }

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

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = manager.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                    manager.statusMessage = "Ready"
                    manager.isHotkeyReady = true
                    Task { @MainActor in
                        AppStatusCenter.shared.setHotkey(ready: true, message: manager.statusMessage)
                    }
                    print("[Hotkey] Re-enabled event tap after system disable")
                }
                return Unmanaged.passUnretained(event)
            }
            
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // Modifier-only triggers arrive as flagsChanged events.
            if keyCode == manager.keyCode {
                let isTriggerPressed = manager.triggerIsPressed(in: flags)
                
                if type == .flagsChanged && isTriggerPressed && !manager.isRecording {
                    print("[Hotkey] Trigger pressed")
                    manager.isRecording = true
                    manager.triggerPressedAt = CFAbsoluteTimeGetCurrent()
                    manager.releaseVerificationWorkItem?.cancel()
                    manager.releaseVerificationWorkItem = nil
                    DispatchQueue.main.async {
                        manager.onTriggerPressed?()
                    }
                } else if type == .flagsChanged && !isTriggerPressed && manager.isRecording {
                    let heldDuration = CFAbsoluteTimeGetCurrent() - manager.triggerPressedAt
                    print("[Hotkey] Trigger release candidate after \(String(format: "%.3f", heldDuration))s")
                    manager.scheduleReleaseVerification(heldDuration: heldDuration)
                }
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

        guard let eventTap = eventTap else {
            isHotkeyReady = false
            statusMessage = "Failed to create event tap"
            Task { @MainActor in
                AppStatusCenter.shared.setHotkey(ready: false, message: self.statusMessage)
            }
            print("[Hotkey] Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        isHotkeyReady = true
        statusMessage = "Ready"
        Task { @MainActor in
            AppStatusCenter.shared.setHotkey(ready: true, message: self.statusMessage)
        }

        print("[Hotkey] Registered trigger: \(trigger.displayName)")
    }

    func unregister() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
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
        print("[Hotkey] Recording state reset")
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
                print("[Hotkey] Ignored false release; trigger still physically pressed")
                return
            }

            print("[Hotkey] Trigger release confirmed")
            self.isRecording = false
            DispatchQueue.main.async {
                self.onTriggerReleased?()
            }
        }

        releaseVerificationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    deinit {
        unregister()
    }
}
