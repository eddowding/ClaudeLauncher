import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    private var bottomY: CGFloat = 0
    private var centerX: CGFloat = 0
    private var hostingView: NSHostingView<ContentView>?
    private var sizeObserver: NSKeyValueObservation?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false

        // Frosted glass
        let visualEffect = NSVisualEffectView(frame: .zero)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        contentView = visualEffect

        let hv = NSHostingView(rootView: ContentView(panel: self))
        hv.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hv)
        NSLayoutConstraint.activate([
            hv.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hv.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hv.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hv.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])
        hostingView = hv

        positionBottomCenter()

        // Watch the hosting view's intrinsic size and resize window to match
        sizeObserver = hv.observe(\.intrinsicContentSize, options: [.new]) { [weak self] view, _ in
            DispatchQueue.main.async {
                self?.resizeToFitContent()
            }
        }
    }

    func positionBottomCenter() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let vf = screen.visibleFrame
        centerX = vf.origin.x + (vf.width - 680) / 2
        bottomY = vf.origin.y + 24

        setFrameOrigin(NSPoint(x: centerX, y: bottomY))
    }

    func resizeToFitContent() {
        guard let hv = hostingView else { return }
        let ideal = hv.fittingSize
        let newHeight = min(max(ideal.height, 56), 500)
        let newFrame = NSRect(x: centerX, y: bottomY, width: 680, height: newHeight)
        setFrame(newFrame, display: true, animate: true)
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
