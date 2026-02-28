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
        panel.onTap = { [weak self] in
            self?.calendarManager.model.toggleEventDetails()
        }
        self.overlayPanel = panel

        if calendarManager.isSignedIn {
            calendarManager.startPolling()
        }

        observeOverlayState()
    }

    private func observeOverlayState() {
        withObservationTracking {
            _ = calendarManager.model.shouldShowOverlay
            _ = calendarManager.model.showingEventDetails
            _ = calendarManager.model.isIdle
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updatePanel()
                self?.observeOverlayState()
            }
        }
    }

    private func updatePanel() {
        guard let panel = overlayPanel else { return }

        if calendarManager.model.shouldShowOverlay {
            panel.ignoresMouseEvents = false

            let height: CGFloat = calendarManager.model.showingEventDetails ? 150 : 100
            let width: CGFloat = 200
            let topEdge = panel.frame.origin.y + panel.frame.height
            panel.setFrame(NSRect(
                x: panel.frame.origin.x,
                y: topEdge - height,
                width: width,
                height: height
            ), display: true)

            panel.orderFront(nil)
        } else {
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }
}

struct OverlayContent: View {
    @Bindable var manager: CalendarManager

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        Group {
            if manager.model.shouldShowOverlay {
                VStack(spacing: 4) {
                    CircleView(
                        minutesRemaining: manager.model.minutesRemaining,
                        colourProgress: manager.model.colourProgress,
                        isFlashing: manager.model.isFlashing,
                        isIdle: manager.model.isIdle
                    )

                    if manager.model.showingEventDetails, let event = manager.model.nextEvent {
                        VStack(spacing: 2) {
                            Text(event.summary)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            Text("\(timeFormatter.string(from: event.startTime)) – \(timeFormatter.string(from: event.endTime))")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .frame(width: 200)
        .fixedSize(horizontal: false, vertical: true)
        .background(.clear)
    }
}
