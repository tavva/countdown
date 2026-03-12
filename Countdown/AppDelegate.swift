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
    private var settingsPanel: NSPanel?
    private var panelTopEdge: CGFloat = 0
    private var panelX: CGFloat = 0
    private var contentHeight: CGFloat = 0
    private var contentWidth: CGFloat = 0
    private var lastCompactState: Bool = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let circleContent = OverlayContent(manager: calendarManager, onContentHeight: { [weak self] height in
            guard let self, height > 0 else { return }
            guard OverlayLayout.shouldApplyMeasuredSize(current: self.contentHeight, measured: height) else { return }
            self.contentHeight = OverlayLayout.normalizedSize(height)
            DispatchQueue.main.async { [weak self] in
                self?.updatePanel()
            }
        }, onContentWidth: { [weak self] width in
            guard let self, width > 0 else { return }
            guard OverlayLayout.shouldApplyMeasuredSize(current: self.contentWidth, measured: width) else { return }
            self.contentWidth = OverlayLayout.normalizedSize(width)
            DispatchQueue.main.async { [weak self] in
                self?.updatePanel()
            }
        })
        let panel = OverlayPanel(content: circleContent)
        panel.onTap = { [weak self] in
            guard let model = self?.calendarManager.model else { return }
            if model.isFlashing {
                model.acknowledgeFlash()
            } else {
                model.toggleEventDetails()
            }
        }
        panel.onSettings = { [weak self] in
            self?.showSettingsPanel()
        }
        panel.onToggleCompact = { [weak self] in
            self?.calendarManager.model.toggleCompactMode()
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
            _ = calendarManager.model.compactMode
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updatePanel()
                self?.observeOverlayState()
            }
        }
    }

    private func showSettingsPanel() {
        if let existing = settingsPanel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Countdown Settings"
        panel.contentView = NSHostingView(rootView: SettingsView(manager: calendarManager))
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsPanel = panel
    }

    private func updatePanel() {
        guard let panel = overlayPanel else { return }

        if calendarManager.model.shouldShowOverlay {
            let compact = calendarManager.model.compactMode
            if compact != lastCompactState {
                contentHeight = 0
                contentWidth = 0
                lastCompactState = compact
            }
            // Generous fallbacks avoid clipping during mode transitions;
            // the measurement callback quickly shrinks the panel to fit.
            let height: CGFloat = contentHeight > 0 ? contentHeight : (compact ? 36 : 200)
            let width: CGFloat = compact ? (contentWidth > 0 ? contentWidth : 400) : 200
            panel.setFrame(NSRect(
                x: panelX,
                y: panelTopEdge - height,
                width: width,
                height: height
            ), display: true)
            panel.isCompact = compact

            panel.ignoresMouseEvents = false
            panel.orderFront(nil)
        } else {
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }
}

enum OverlayLayout {
    static func normalizedSize(_ measured: CGFloat) -> CGFloat {
        measured.rounded(.up)
    }

    static func shouldApplyMeasuredSize(current: CGFloat, measured: CGFloat) -> Bool {
        let normalized = normalizedSize(measured)
        guard normalized > 0 else { return false }
        return normalized != current
    }
}

private struct ContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ContentWidthKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct OverlayContent: View {
    @Bindable var manager: CalendarManager
    var onContentHeight: ((CGFloat) -> Void)?
    var onContentWidth: ((CGFloat) -> Void)?

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        Group {
            if manager.model.shouldShowOverlay {
                if manager.model.compactMode {
                    compactLayout
                } else {
                    standardLayout
                }
            }
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            onContentHeight?(height)
        }
        .onPreferenceChange(ContentWidthKey.self) { width in
            onContentWidth?(width)
        }
        .background(.clear)
    }

    @ViewBuilder
    private var standardLayout: some View {
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
                eventDetailsBox(event: event)
            }
        }
        .frame(width: 200)
        .background(GeometryReader { geo in
            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
        })
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var compactLayout: some View {
        HStack(spacing: 6) {
            CircleView(
                minutesRemaining: manager.model.minutesRemaining,
                colourProgress: manager.model.colourProgress,
                isFlashing: manager.model.isFlashing,
                isIdle: manager.model.isIdle,
                isLoading: manager.model.isLoading,
                ringProgress: manager.model.ringProgress,
                compact: true
            )

            if !manager.model.isLoading && !manager.model.isIdle {
                Text("\(manager.model.minutesRemaining)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            if manager.model.showingEventDetails, let event = manager.model.displayedEvent {
                Text("\(event.summary) – \(timeFormatter.string(from: event.startTime))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .fixedSize(horizontal: true, vertical: false)
        .background(.black.opacity(0.7), in: Capsule())
        .background(GeometryReader { geo in
            Color.clear
                .preference(key: ContentHeightKey.self, value: geo.size.height)
                .preference(key: ContentWidthKey.self, value: geo.size.width)
        })
    }

    @ViewBuilder
    private func eventDetailsBox(event: CalendarEvent) -> some View {
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
