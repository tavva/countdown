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
    private var panelTopEdge: CGFloat = 0
    private var panelX: CGFloat = 0

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let circleContent = OverlayContent(manager: calendarManager)
        let panel = OverlayPanel(content: circleContent)
        panel.onTap = { [weak self] in
            guard let model = self?.calendarManager.model else { return }
            if model.isFlashing {
                model.acknowledgeFlash()
            } else {
                model.toggleEventDetails()
            }
        }
        panel.onPositionChange = { [weak self] in
            guard let self, let panel = self.overlayPanel else { return }
            self.panelTopEdge = panel.frame.origin.y + panel.frame.height
            self.panelX = panel.frame.origin.x
        }
        self.overlayPanel = panel
        panel.ensureOnScreen()
        panelTopEdge = panel.frame.origin.y + panel.frame.height
        panelX = panel.frame.origin.x

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )

        if calendarManager.isSignedIn {
            calendarManager.startPolling()
        }

        updatePanel()
        observeOverlayState()
    }

    @objc private func screenDidChange(_ notification: Notification) {
        guard let panel = overlayPanel else { return }
        panel.ensureOnScreen()
        panelTopEdge = panel.frame.origin.y + panel.frame.height
        panelX = panel.frame.origin.x
    }

    private func observeOverlayState() {
        withObservationTracking {
            _ = calendarManager.model.shouldShowOverlay
            _ = calendarManager.model.showingEventDetails
            _ = calendarManager.model.isIdle
            _ = calendarManager.model.isLoading
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
            let height: CGFloat = calendarManager.model.showingEventDetails ? 170 : 120
            let width: CGFloat = 200
            panel.setFrame(NSRect(
                x: panelX,
                y: panelTopEdge - height,
                width: width,
                height: height
            ), display: true)

            panel.ignoresMouseEvents = false
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
                        isIdle: manager.model.isIdle,
                        isLoading: manager.model.isLoading,
                        ringProgress: manager.model.ringProgress
                    )

                    if manager.model.showingEventDetails, let event = manager.model.displayedEvent {
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
