import AppKit

final class FloatingPanelController {
    private let panel: NSPanel
    private let blurView: NSVisualEffectView
    private let stackView = NSStackView()
    private let waveformView = WaveformView()
    private let textField = NSTextField(labelWithString: "")
    private var widthConstraint: NSLayoutConstraint?

    private let minTextWidth: CGFloat = 160
    private let maxTextWidth: CGFloat = 560
    private let panelHeight: CGFloat = 56

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 244, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        blurView = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = panelHeight / 2
        blurView.layer?.masksToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 18)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .systemFont(ofSize: 16, weight: .medium)
        textField.textColor = .white
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1

        stackView.addArrangedSubview(waveformView)
        stackView.addArrangedSubview(textField)

        blurView.addSubview(stackView)
        panel.contentView = NSView()
        panel.contentView?.addSubview(blurView)

        widthConstraint = textField.widthAnchor.constraint(equalToConstant: minTextWidth)
        widthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: blurView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),

            waveformView.widthAnchor.constraint(equalToConstant: 44),
            waveformView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    func show(text: String) {
        update(text: text)
        positionPanel()
        panel.alphaValue = 0
        panel.setFrame(NSRect(origin: panel.frame.origin, size: panel.frame.size), display: true)
        panel.orderFrontRegardless()

        blurView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.88, y: 0.88))
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            blurView.layer?.setAffineTransform(.identity)
        }
    }

    func update(text: String) {
        let displayText = text.isEmpty ? "Listening..." : text
        textField.stringValue = displayText
        let measured = ceil((displayText as NSString).size(withAttributes: [.font: textField.font as Any]).width) + 12
        let textWidth = min(max(measured, minTextWidth), maxTextWidth)

        guard abs((widthConstraint?.constant ?? 0) - textWidth) > 1 else {
            return
        }

        widthConstraint?.constant = textWidth
        let newWidth = 44 + 12 + textWidth + 34
        let newFrame = frameFor(width: newWidth)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = panel.isVisible ? 0.25 : 0
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
            panel.contentView?.layoutSubtreeIfNeeded()
        }
    }

    func setStatus(_ status: String) {
        update(text: status)
    }

    func updateRMS(_ rms: Float) {
        waveformView.update(rms: rms)
    }

    func hide() {
        guard panel.isVisible else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            blurView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.92, y: 0.92))
        } completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
            self?.blurView.layer?.setAffineTransform(.identity)
        }
    }

    private func positionPanel() {
        panel.setFrame(frameFor(width: panel.frame.width), display: true)
    }

    private func frameFor(width: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + 64
        return NSRect(x: x, y: y, width: width, height: panelHeight)
    }
}

final class WaveformView: NSView {
    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var envelope: CGFloat = 0
    private var displayLink: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func update(rms: Float) {
        let target = CGFloat(min(max(rms, 0), 1))
        let coefficient: CGFloat = target > envelope ? 0.4 : 0.15
        envelope += (target - envelope) * coefficient
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.white.withAlphaComponent(0.92).setFill()

        let barWidth: CGFloat = 5
        let spacing: CGFloat = 4
        let totalWidth = CGFloat(weights.count) * barWidth + CGFloat(weights.count - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.midY
        let minHeight: CGFloat = 7
        let maxHeight = bounds.height - 2

        for (index, weight) in weights.enumerated() {
            let jitter = CGFloat.random(in: -0.04...0.04)
            let scaled = max(0, min(1, envelope * weight * (1 + jitter)))
            let height = minHeight + scaled * (maxHeight - minHeight)
            let x = startX + CGFloat(index) * (barWidth + spacing)
            let rect = NSRect(x: x, y: centerY - height / 2, width: barWidth, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            path.fill()
        }
    }
}
