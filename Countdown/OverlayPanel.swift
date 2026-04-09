// ABOUTME: Floating borderless panel that displays the countdown circle on the desktop.
// ABOUTME: Positions itself in a configured corner (or saved position) and stays above all windows.

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

    static func clampedOrigin(origin: CGPoint, panelSize: CGSize, screenFrames: [CGRect]) -> CGPoint? {
        let centre = CGPoint(x: origin.x + panelSize.width / 2, y: origin.y + panelSize.height / 2)
        if screenFrames.contains(where: { $0.contains(centre) }) { return nil }
        guard !screenFrames.isEmpty else { return nil }

        let nearestScreen = screenFrames.min(by: {
            distanceSquared(from: centre, to: $0) < distanceSquared(from: centre, to: $1)
        })!

        let clampedCentreX = min(max(centre.x, nearestScreen.minX), nearestScreen.maxX)
        let clampedCentreY = min(max(centre.y, nearestScreen.minY), nearestScreen.maxY)

        return CGPoint(
            x: clampedCentreX - panelSize.width / 2,
            y: clampedCentreY - panelSize.height / 2
        )
    }

    private static func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    static func cornerOrigin(corner: ScreenCorner, visibleFrame: CGRect, panelSize: CGSize) -> CGPoint {
        let padding: CGFloat = 20
        let x: CGFloat
        let y: CGFloat
        switch corner {
        case .topLeft:
            x = visibleFrame.minX + padding
            y = visibleFrame.maxY - panelSize.height - padding
        case .topRight:
            x = visibleFrame.maxX - panelSize.width - padding
            y = visibleFrame.maxY - panelSize.height - padding
        case .bottomLeft:
            x = visibleFrame.minX + padding
            y = visibleFrame.minY + padding
        case .bottomRight:
            x = visibleFrame.maxX - panelSize.width - padding
            y = visibleFrame.minY + padding
        }
        return CGPoint(x: x, y: y)
    }
}

struct OverlayFramePlacement {
    private var anchor: ScreenCorner
    private var anchorX: CGFloat  // left edge for left anchors, right edge for right anchors
    private var anchorY: CGFloat  // top edge for top anchors, bottom edge for bottom anchors
    private var restoredOrigin: CGPoint?

    init(initialFrame: CGRect, restoredOrigin: CGPoint?, anchor: ScreenCorner = .topLeft) {
        self.anchor = anchor
        self.anchorX = Self.referenceX(for: initialFrame, anchor: anchor)
        self.anchorY = Self.referenceY(for: initialFrame, anchor: anchor)
        self.restoredOrigin = restoredOrigin
    }

    mutating func setAnchor(_ newAnchor: ScreenCorner, currentFrame: CGRect) {
        self.anchor = newAnchor
        self.anchorX = Self.referenceX(for: currentFrame, anchor: newAnchor)
        self.anchorY = Self.referenceY(for: currentFrame, anchor: newAnchor)
        self.restoredOrigin = nil
    }

    mutating func frame(for size: CGSize) -> CGRect {
        if let restoredOrigin {
            self.restoredOrigin = nil
            let newFrame = CGRect(origin: restoredOrigin, size: size)
            self.anchorX = Self.referenceX(for: newFrame, anchor: anchor)
            self.anchorY = Self.referenceY(for: newFrame, anchor: anchor)
            return newFrame
        }

        let originX: CGFloat
        let originY: CGFloat
        switch anchor {
        case .topLeft:
            originX = anchorX
            originY = anchorY - size.height
        case .topRight:
            originX = anchorX - size.width
            originY = anchorY - size.height
        case .bottomLeft:
            originX = anchorX
            originY = anchorY
        case .bottomRight:
            originX = anchorX - size.width
            originY = anchorY
        }
        return CGRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    mutating func record(frame: CGRect) {
        anchorX = Self.referenceX(for: frame, anchor: anchor)
        anchorY = Self.referenceY(for: frame, anchor: anchor)
        restoredOrigin = nil
    }

    private static func referenceX(for frame: CGRect, anchor: ScreenCorner) -> CGFloat {
        switch anchor {
        case .topLeft, .bottomLeft: return frame.minX
        case .topRight, .bottomRight: return frame.maxX
        }
    }

    private static func referenceY(for frame: CGRect, anchor: ScreenCorner) -> CGFloat {
        switch anchor {
        case .topLeft, .topRight: return frame.maxY
        case .bottomLeft, .bottomRight: return frame.minY
        }
    }
}

enum CircleHitTest {
    static let radius: CGFloat = 45
    static let centreOffsetFromTop: CGFloat = 55

    static func isInsideCircle(point: CGPoint, viewSize: CGSize, compact: Bool) -> Bool {
        if compact { return true }
        let centreX = viewSize.width / 2.0
        let centreY = viewSize.height - centreOffsetFromTop
        let distance = hypot(point.x - centreX, point.y - centreY)
        return distance <= radius
    }
}

class CircleHitTestView: NSView {
    var isCompact: Bool = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard CircleHitTest.isInsideCircle(point: point, viewSize: bounds.size, compact: isCompact) else { return nil }
        return super.hitTest(point)
    }
}

final class OverlayPanel: NSPanel {
    var onTap: (() -> Void)?
    var onPositionChange: (() -> Void)?
    var onSettings: (() -> Void)?
    var onToggleCompact: (() -> Void)?

    var isCompact: Bool = false {
        didSet { (contentView as? CircleHitTestView)?.isCompact = isCompact }
    }

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

        let compactItem = NSMenuItem(title: "Compact mode", action: #selector(compactMenuAction), keyEquivalent: "")
        compactItem.target = self
        compactItem.state = isCompact ? .on : .off
        menu.addItem(compactItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(settingsMenuAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Countdown", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: event, for: contentView!)
    }

    @objc private func compactMenuAction(_ sender: Any?) {
        onToggleCompact?()
    }

    @objc private func settingsMenuAction(_ sender: Any?) {
        onSettings?()
    }

    func positionInCorner(_ corner: ScreenCorner) {
        guard let screen = self.screen ?? NSScreen.main else { return }
        let origin = OverlayPosition.cornerOrigin(
            corner: corner,
            visibleFrame: screen.visibleFrame,
            panelSize: frame.size
        )
        setFrameOrigin(origin)
        OverlayPosition.save(origin)
    }

    func positionTopLeft() {
        positionInCorner(.topLeft)
    }

    func ensureOnScreen() {
        let screenFrames = NSScreen.screens.map(\.frame)
        if let clamped = OverlayPosition.clampedOrigin(origin: frame.origin, panelSize: frame.size, screenFrames: screenFrames) {
            setFrameOrigin(clamped)
            OverlayPosition.save(frame.origin)
        }
    }
}
