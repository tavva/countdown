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
    var onPositionChange: (() -> Void)?

    private var initialMouseLocation: CGPoint = .zero
    private var initialWindowOrigin: CGPoint = .zero
    private var didDrag = false
    private var isTrackingMouse = false

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
        contentView = hostingView

        if let saved = OverlayPosition.restore() {
            setFrameOrigin(saved)
        } else {
            positionBottomRight()
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let location = event.locationInWindow
            let centerX = frame.width / 2.0
            let centerY = frame.height - 60.0
            let distance = hypot(location.x - centerX, location.y - centerY)
            guard distance <= 45 else { return }
            isTrackingMouse = true
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            guard isTrackingMouse else { return }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            guard isTrackingMouse else { return }
            isTrackingMouse = false
        default:
            break
        }
        super.sendEvent(event)
    }

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

    func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 20
        let frame = NSRect(
            x: screen.visibleFrame.maxX - 200 - padding,
            y: screen.visibleFrame.minY + padding,
            width: 200,
            height: 120
        )
        setFrame(frame, display: true)
    }
}
