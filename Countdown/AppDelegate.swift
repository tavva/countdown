// ABOUTME: Manages app activation policy to suppress Dock icon.
// ABOUTME: Owns the floating overlay panel lifecycle.

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayPanel: OverlayPanel?
    var calendarManager: CalendarManager?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func setupOverlay(manager: CalendarManager) {
        self.calendarManager = manager

        let circleContent = OverlayContent(manager: manager)
        let panel = OverlayPanel(content: circleContent)
        self.overlayPanel = panel
    }
}

struct OverlayContent: View {
    @Bindable var manager: CalendarManager

    var body: some View {
        Group {
            if manager.model.shouldShowOverlay {
                CircleView(
                    minutesRemaining: manager.model.minutesRemaining,
                    colourProgress: manager.model.colourProgress,
                    isFlashing: manager.model.isFlashing,
                    onDismiss: { manager.model.dismiss() }
                )
            }
        }
        .frame(width: 100, height: 100)
        .background(.clear)
        .onChange(of: manager.model.shouldShowOverlay) { _, visible in
            if visible {
                (NSApp.delegate as? AppDelegate)?.overlayPanel?.orderFront(nil)
            } else {
                (NSApp.delegate as? AppDelegate)?.overlayPanel?.orderOut(nil)
            }
        }
    }
}
