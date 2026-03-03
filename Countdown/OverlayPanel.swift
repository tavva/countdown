// ABOUTME: Floating borderless panel that displays the countdown circle on the desktop.
// ABOUTME: Positions itself in the top-left corner (or saved position) and stays above all windows.

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

    static func isVisible(origin: CGPoint, panelSize: CGSize, screenFrames: [CGRect]) -> Bool {
        let centre = CGPoint(x: origin.x + panelSize.width / 2, y: origin.y + panelSize.height / 2)
        return screenFrames.contains { $0.contains(centre) }
    }
}

enum CircleHitTest {
    static let radius: CGFloat = 45
    static let centreOffsetFromTop: CGFloat = 60

    static func isInsideCircle(point: CGPoint, viewSize: CGSize) -> Bool {
        let centreX = viewSize.width / 2.0
        let centreY = viewSize.height - centreOffsetFromTop
        let distance = hypot(point.x - centreX, point.y - centreY)
        return distance <= radius
    }
}

class CircleHitTestView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard CircleHitTest.isInsideCircle(point: point, viewSize: bounds.size) else { return nil }
        return super.hitTest(point)
    }
}

final class OverlayPanel: NSPanel {
    var onTap: (() -> Void)?
    var onPositionChange: (() -> Void)?

    private var initialMouseLocation: CGPoint = .zero
    private var initialWindowOrigin: CGPoint = .zero
    private var didDrag = false

    init<Content: View>(content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
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
        hostingView.layer?.isOpaque = false
        hostingView.layer?.backgroundColor = nil

        let container = CircleHitTestView(frame: NSRect(x: 0, y: 0, width: 200, height: 120))
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        contentView = container

        if let saved = OverlayPosition.restore() {
            setFrameOrigin(saved)
        } else {
            positionTopLeft()
        }
    }

    override var canBecomeKey: Bool { false }
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
            onPositionChange?()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            OverlayPosition.save(frame.origin)
            onPositionChange?()
        } else {
            onTap?()
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Countdown", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: event, for: contentView!)
    }

    func positionTopLeft() {
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 20
        let frame = NSRect(
            x: screen.visibleFrame.minX + padding,
            y: screen.visibleFrame.maxY - 120 - padding,
            width: 200,
            height: 120
        )
        setFrame(frame, display: true)
    }

    func ensureOnScreen() {
        let screenFrames = NSScreen.screens.map(\.frame)
        if !OverlayPosition.isVisible(origin: frame.origin, panelSize: frame.size, screenFrames: screenFrames) {
            positionTopLeft()
            OverlayPosition.save(frame.origin)
        }
    }
}
