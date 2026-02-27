// ABOUTME: Floating borderless panel that displays the countdown circle on the desktop.
// ABOUTME: Positions itself in the bottom-right corner and stays above all windows.

import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
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

        positionBottomRight()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

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
