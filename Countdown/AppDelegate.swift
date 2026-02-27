// ABOUTME: Manages app activation policy, overlay panel, and calendar polling lifecycle.
// ABOUTME: Owns the CalendarManager so polling starts at launch, not on first popover open.

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let calendarManager: CalendarManager = {
        let mgr = CalendarManager()
        mgr.config = Config.load()
        return mgr
    }()

    var overlayPanel: OverlayPanel?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let circleContent = OverlayContent(manager: calendarManager)
        let panel = OverlayPanel(content: circleContent)
        panel.ignoresMouseEvents = true
        panel.orderFront(nil)
        self.overlayPanel = panel

        if calendarManager.isSignedIn {
            calendarManager.startPolling()
        }
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
            (NSApp.delegate as? AppDelegate)?.overlayPanel?.ignoresMouseEvents = !visible
        }
    }
}
