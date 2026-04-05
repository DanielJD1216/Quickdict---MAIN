import AppKit

enum RecordingIndicatorState {
    case recording
    case processing
    case done
    case error(String)

    var title: String {
        switch self {
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .done:
            return "Done"
        case .error:
            return "Error"
        }
    }

    var color: NSColor {
        switch self {
        case .recording:
            return .systemRed
        case .processing:
            return .systemOrange
        case .done:
            return .systemGreen
        case .error:
            return .systemRed
        }
    }
}

final class RecordingIndicatorWindow: NSWindow {
    private var pulseAnimation: Timer?
    private let visualEffect = NSVisualEffectView()
    private let indicator = NSView()
    private let label = NSTextField(labelWithString: "Recording")

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        setupContent()
        positionWindow()
    }

    private func setupContent() {
        visualEffect.frame = NSRect(x: 0, y: 0, width: 180, height: 40)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20

        let stackView = NSStackView(frame: NSRect(x: 16, y: 10, width: 148, height: 20))
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.alignment = .centerY

        indicator.frame = NSRect(x: 0, y: 4, width: 10, height: 10)
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = NSColor.systemRed.cgColor
        indicator.layer?.cornerRadius = 5

        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white

        stackView.addArrangedSubview(indicator)
        stackView.addArrangedSubview(label)

        visualEffect.addSubview(stackView)
        self.contentView = visualEffect
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame

        let x = screenFrame.midX - (windowFrame.width / 2)
        let y = screenFrame.maxY - windowFrame.height - 14

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func show(state: RecordingIndicatorState) {
        apply(state: state)
        positionWindow()
        self.orderFront(nil)
        startPulseAnimation()
    }

    func hide() {
        stopPulseAnimation()
        self.orderOut(nil)
    }

    func apply(state: RecordingIndicatorState) {
        label.stringValue = state.title
        indicator.layer?.backgroundColor = state.color.cgColor
    }

    private func startPulseAnimation() {
        var alpha: CGFloat = 1.0
        var increasing = false

        pulseAnimation?.invalidate()
        pulseAnimation = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            if increasing {
                alpha += 0.05
                if alpha >= 1.0 {
                    increasing = false
                }
            } else {
                alpha -= 0.05
                if alpha <= 0.3 {
                    increasing = true
                }
            }

            self.indicator.layer?.opacity = Float(alpha)
        }
    }

    private func stopPulseAnimation() {
        pulseAnimation?.invalidate()
        pulseAnimation = nil
    }

    deinit {
        stopPulseAnimation()
    }
}
