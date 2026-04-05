import AppKit
import SwiftUI
import ApplicationServices
import AVFoundation
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, AudioCaptureDelegate {
    var mainWindow: NSWindow?
    var statusItem: NSStatusItem?
    var recordingIndicator: RecordingIndicatorWindow?
    let appStatus = AppStatusCenter.shared
    private var timedStopWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var currentTargetContext: DictationTargetContext?

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermissions()
        syncASRStatus()
        setupMainWindow()
        setupMenuBar()
        setupHotkey()
        observeAppCommands()
        AudioCaptureManager.shared.delegate = self
        
        print("[Quickdict] App launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        AudioCaptureManager.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            print("[AppDelegate] Accessibility permissions granted")
        } else {
            print("[AppDelegate] Accessibility permissions denied - paste/selection features may not work")
            showAccessibilityAlert()
        }

        appStatus.setAccessibility(granted: trusted)
    }

    private func observeAppCommands() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleStartDictationRequest), name: Notification.Name("quickdict.startDictation"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleStopDictationRequest), name: Notification.Name("quickdict.stopDictation"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePermissionRequest), name: Notification.Name("quickdict.checkPermissions"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTimedTestDictationRequest), name: Notification.Name("quickdict.runTimedTestDictation"), object: nil)
    }

    @objc private func handleStartDictationRequest() {
        startDictation()
    }

    @objc private func handleStopDictationRequest() {
        stopDictation()
    }

    @objc private func handlePermissionRequest() {
        checkAccessibilityPermissions()

        let hasInputMonitoring = CGPreflightListenEventAccess()
        if !hasInputMonitoring {
            _ = CGRequestListenEventAccess()
        }

        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch microphoneStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.showPermissionStatusAlert(accessibility: self.appStatus.accessibilityGranted, inputMonitoring: CGPreflightListenEventAccess(), microphone: granted)
                }
            }
            return
        case .authorized:
            break
        case .denied, .restricted:
            break
        @unknown default:
            break
        }

        showPermissionStatusAlert(accessibility: appStatus.accessibilityGranted, inputMonitoring: CGPreflightListenEventAccess(), microphone: microphoneStatus == .authorized)
    }

    @objc private func handleTimedTestDictationRequest() {
        guard appStatus.dictationState != .recording else { return }

        startDictation()

        let workItem = DispatchWorkItem { [weak self] in
            self?.stopDictation()
        }
        timedStopWorkItem?.cancel()
        timedStopWorkItem = workItem
        appStatus.setOutputMessage("Running 3-second timed dictation test...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    private func showPermissionStatusAlert(accessibility: Bool, inputMonitoring: Bool, microphone: Bool) {
        let alert = NSAlert()
        alert.messageText = "Permission Status"
        alert.informativeText = "Accessibility: \(accessibility ? "Enabled" : "Missing")\nInput Monitoring: \(inputMonitoring ? "Enabled" : "Missing")\nMicrophone: \(microphone ? "Enabled" : "Missing")\n\nIf you just changed Accessibility or Input Monitoring in System Settings, quit and relaunch Quickdict before checking again."
        alert.alertStyle = accessibility && inputMonitoring && microphone ? .informational : .warning
        alert.addButton(withTitle: "Open Privacy Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permissions Required"
            alert.informativeText = "Quickdict needs:\n\n1. Accessibility for text insertion and selected-text detection\n2. Input Monitoring for modifier-only trigger keys like Right Option\n\nPlease go to System Settings → Privacy & Security and enable Quickdict in both Accessibility and Input Monitoring."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func setupMainWindow() {
        let contentView = MainWindow()

        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        mainWindow?.title = "Quickdict"
        mainWindow?.minSize = NSSize(width: 900, height: 600)
        mainWindow?.contentView = NSHostingView(rootView: contentView)
        mainWindow?.center()
        mainWindow?.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Quickdict")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Quickdict", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Start Dictation", action: #selector(startDictation), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func startDictation() {
        guard appStatus.dictationState != .recording else { return }
        guard appStatus.asrReady else {
            let message = appStatus.asrMessage
            appStatus.dictationState = .error(message)
            appStatus.lastTranscript = message
            appStatus.setOutputMessage("Dictation blocked: \(message)")
            showIndicator(.error(message))
            hideIndicator(after: 1.2)
            return
        }

        currentTargetContext = OutputManager.shared.captureTargetContext(includeSelectedText: SettingsManager.shared.transformSelectedText)
        appStatus.dictationState = .recording
        appStatus.setOutputMessage("Listening...")
        showIndicator(.recording)
        AudioCaptureManager.shared.startRecording()
    }

    private func stopDictation() {
        guard appStatus.dictationState == .recording else { return }
        timedStopWorkItem?.cancel()
        timedStopWorkItem = nil
        HotkeyManager.shared.stopRecording()
        appStatus.dictationState = .processing
        appStatus.setOutputMessage("Processing audio...")
        showIndicator(.processing)
        AudioCaptureManager.shared.stopRecording()
    }

    private func setupHotkey() {
        HotkeyManager.shared.onTriggerPressed = { [weak self] in
            self?.startDictation()
        }
        HotkeyManager.shared.onTriggerReleased = { [weak self] in
            self?.stopDictation()
        }
        HotkeyManager.shared.register(trigger: SettingsManager.shared.triggerConfiguration)
        observeTriggerSettings()
        print("[AppDelegate] Hotkey registered")
    }

    private func observeTriggerSettings() {
        let settings = SettingsManager.shared

        Publishers.CombineLatest3(settings.$triggerKey, settings.$customTriggerKeyCode, settings.$customTriggerModifiers)
            .receive(on: RunLoop.main)
            .sink { _, _, _ in
                HotkeyManager.shared.register(trigger: settings.triggerConfiguration)
            }
            .store(in: &cancellables)

        settings.$selectedModel
            .receive(on: RunLoop.main)
            .sink { _ in
                self.syncASRStatus()
            }
            .store(in: &cancellables)
    }

    private func showIndicator(_ state: RecordingIndicatorState) {
        if recordingIndicator == nil {
            recordingIndicator = RecordingIndicatorWindow()
        }
        recordingIndicator?.show(state: state)
    }

    private func hideIndicator(after delay: TimeInterval = 0.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.recordingIndicator?.hide()
        }
    }

    private func pipeline() -> TextProcessingPipeline {
        let settings = SettingsManager.shared
        return TextProcessingPipeline(
            removeFillers: settings.removeFillers,
            removeFalseStarts: settings.removeFalseStarts,
            numberConversion: settings.numberConversion,
            autoPunctuation: settings.autoPunctuation,
            bulletPoints: settings.bulletPoints
        )
    }

    private func syncASRStatus() {
        appStatus.setASR(ready: false, message: "Checking Parakeet v3...")
        Task {
            let result = await ASREngine.validateAvailability()
            await MainActor.run {
                self.appStatus.setASR(ready: result.0, message: result.1)
            }
        }
    }

    func audioCapture(_ manager: AudioCaptureManager, didCaptureBuffer buffer: AVAudioPCMBuffer) {}

    func audioCapture(_ manager: AudioCaptureManager, didDetectSpeech start: Bool) {}

    func audioCapture(_ manager: AudioCaptureManager, didFinishWithText text: String) {
        let processedText = pipeline().process(text)
        let settings = SettingsManager.shared
        let targetContext = currentTargetContext
        currentTargetContext = nil

        if settings.transformSelectedText,
           let selectedText = targetContext?.selectedText,
           !selectedText.isEmpty {
            appStatus.dictationState = .processing
            appStatus.lastTranscript = "Transforming selected text..."
            appStatus.setOutputMessage("Running transform request...")
            appStatus.setTransformDebug("Using model \(settings.selectedTransformModel) on \(selectedText.count) chars")

            Task {
                do {
                    let transformed = try await TransformManager.shared.transform(text: selectedText, command: processedText)
                    await MainActor.run {
                        self.appStatus.setTransformDebug("Transform succeeded, output \(transformed.count) chars")
                        OutputManager.shared.output(text: transformed, settings: settings, target: targetContext)
                        HotkeyManager.shared.stopRecording()
                        self.appStatus.lastTranscript = transformed
                        self.appStatus.dictationState = .done
                        self.appStatus.setOutputMessage("Transformed selected text")
                        self.recordingIndicator?.apply(state: .done)
                        self.hideIndicator(after: 0.7)
                    }
                } catch {
                    await MainActor.run {
                        self.appStatus.setTransformDebug("Transform failed: \(error.localizedDescription)")
                        self.audioCapture(manager, didEncounterError: error)
                    }
                }
            }
            return
        }

        OutputManager.shared.output(text: processedText, settings: settings, target: targetContext)
        HotkeyManager.shared.stopRecording()
        appStatus.lastTranscript = processedText
        appStatus.dictationState = .done
        appStatus.setOutputMessage("Output sent")
        recordingIndicator?.apply(state: .done)
        hideIndicator(after: 0.7)
        print("[AppDelegate] Final output: \(processedText)")
    }

    func audioCapture(_ manager: AudioCaptureManager, didEncounterError error: Error) {
        currentTargetContext = nil
        HotkeyManager.shared.stopRecording()
        appStatus.dictationState = .error(error.localizedDescription)
        appStatus.lastTranscript = error.localizedDescription
        appStatus.setOutputMessage("Output not sent")
        recordingIndicator?.apply(state: .error(error.localizedDescription))
        hideIndicator(after: 1.2)
        print("[AppDelegate] Audio pipeline error: \(error)")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
