// ABOUTME: Floating borderless panel that displays the countdown circle on the desktop.
// ABOUTME: Positions itself in the bottom-right corner (or saved position) and stays above all windows.

import AppKit
import SwiftUI

enum OverlayPosition {
    private static let key = "overlayPosition"

    static func save(_ origin: CGPoint) {
        UserDefaults.standard.set([origin.x, origin.y], forKey: key)
    }

    static func restore() -> CGPoint? {
        guard let array = UserDefaults.standard.array(forKey: key) as? [Double],
              array.count == 2 else { return nil }
        return CGPoint(x: array[0], y: array[1])
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

final class OverlayPanel: NSPanel {
    var onTap: (() -> Void)?

    private var initialMouseLocation: CGPoint = .zero
    private var initialWindowOrigin: CGPoint = .zero
    private var didDrag = false

    init<Content: View>(content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: content)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        contentView = hostingView

        if let saved = OverlayPosition.restore() {
            setFrameOrigin(saved)
        } else {
            positionBottomRight()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - initialMouseLocation.x
        let dy = current.y - initialMouseLocation.y
        if abs(dx) > 3 || abs(dy) > 3 {
            didDrag = true
        }
        if didDrag {
            setFrameOrigin(NSPoint(
                x: initialWindowOrigin.x + dx,
                y: initialWindowOrigin.y + dy
            ))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            OverlayPosition.save(frame.origin)
        } else {
            onTap?()
        }
    }

    func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 20
        let frame = NSRect(
            x: screen.visibleFrame.maxX - 100 - padding,
            y: screen.visibleFrame.minY + padding,
            width: 100,
            height: 100
        )
        setFrame(frame, display: true)
    }
}
