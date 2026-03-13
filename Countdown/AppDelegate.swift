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
    let updateManager = UpdateManager()

    var overlayPanel: OverlayPanel?
    private var settingsPanel: NSPanel?
    private var panelPlacement = OverlayFramePlacement(initialFrame: .zero, restoredOrigin: nil)
    private var measurementCache = OverlayMeasurementCache()
    private var transitionState = OverlayTransitionState()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let circleContent = OverlayContent(manager: calendarManager, onContentHeight: { [weak self] state, height in
            guard let self else { return }
            let shouldRefresh = OverlayMeasurementRouter.handle(
                value: height,
                state: state,
                axis: .height,
                cache: &self.measurementCache,
                transitionState: &self.transitionState
            )
            guard shouldRefresh else { return }
            DispatchQueue.main.async { [weak self] in
                self?.updatePanel()
            }
        }, onContentWidth: { [weak self] state, width in
            guard let self else { return }
            let shouldRefresh = OverlayMeasurementRouter.handle(
                value: width,
                state: state,
                axis: .width,
                cache: &self.measurementCache,
                transitionState: &self.transitionState
            )
            guard shouldRefresh else { return }
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
            self.panelPlacement.record(frame: panel.frame)
        }
        self.overlayPanel = panel
        panel.ensureOnScreen()
        let restoredOrigin = OverlayPosition.restore() != nil ? panel.frame.origin : nil
        panelPlacement = OverlayFramePlacement(initialFrame: panel.frame, restoredOrigin: restoredOrigin)

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
        panelPlacement.record(frame: panel.frame)
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
            let layoutState = OverlayLayoutState(model: calendarManager.model)
            transitionState.prepare(for: layoutState)
            panel.isCompact = layoutState.mode == .compact
            panel.alphaValue = 1

            if OverlayPresentationDecision.shouldHoldCurrentFrame(
                transitionState: transitionState,
                cache: measurementCache,
                targetState: layoutState
            ) {
                panel.ignoresMouseEvents = false
                panel.orderFront(nil)
                return
            }

            let size = measurementCache.size(for: layoutState)
            panel.setFrame(panelPlacement.frame(for: size), display: true)
            panelPlacement.record(frame: panel.frame)

            panel.ignoresMouseEvents = false
            panel.orderFront(nil)
        } else {
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }
}

enum OverlayLayout {
    static let standardWidth: CGFloat = 200
    static let standardFallbackHeight: CGFloat = 200
    static let standardMinimumMeasuredHeight: CGFloat = 110
    static let compactFallbackWidth: CGFloat = 400
    static let compactFallbackHeight: CGFloat = 36
    static let compactMinimumMeasuredWidth: CGFloat = 44
    static let compactMinimumMeasuredHeight: CGFloat = 36

    static func normalizedSize(_ measured: CGFloat) -> CGFloat {
        measured.rounded(.up)
    }

    static func shouldApplyMeasuredSize(current: CGFloat, measured: CGFloat) -> Bool {
        let normalized = normalizedSize(measured)
        guard normalized > 0 else { return false }
        return normalized != current
    }
}

enum OverlayDisplayMode: Equatable {
    case standard
    case compact
}

struct OverlayLayoutState: Hashable, Equatable {
    let mode: OverlayDisplayMode
    let showsEventDetails: Bool
    let showsCompactMinutes: Bool

    init(mode: OverlayDisplayMode, showsEventDetails: Bool, showsCompactMinutes: Bool) {
        self.mode = mode
        self.showsEventDetails = showsEventDetails
        self.showsCompactMinutes = showsCompactMinutes
    }

    init(model: CountdownModel) {
        let mode: OverlayDisplayMode = model.compactMode ? .compact : .standard
        self.mode = mode
        self.showsEventDetails = model.showingEventDetails && model.displayedEvent != nil
        self.showsCompactMinutes = mode == .compact && !model.isLoading && !model.isIdle
    }

    static func defaultState(for mode: OverlayDisplayMode) -> OverlayLayoutState {
        OverlayLayoutState(mode: mode, showsEventDetails: false, showsCompactMinutes: false)
    }
}

enum OverlayMeasurementAxis {
    case height
    case width
}

enum OverlayMeasurementValidation {
    static func isValid(_ measured: CGFloat, for state: OverlayLayoutState, axis: OverlayMeasurementAxis) -> Bool {
        isValid(measured, for: state.mode, axis: axis)
    }

    static func isValid(_ measured: CGFloat, for mode: OverlayDisplayMode, axis: OverlayMeasurementAxis) -> Bool {
        let normalized = OverlayLayout.normalizedSize(measured)
        guard normalized > 0 else { return false }

        let minimum: CGFloat
        switch (mode, axis) {
        case (.standard, .height):
            minimum = OverlayLayout.standardMinimumMeasuredHeight
        case (.standard, .width):
            minimum = OverlayLayout.standardWidth
        case (.compact, .height):
            minimum = OverlayLayout.compactMinimumMeasuredHeight
        case (.compact, .width):
            minimum = OverlayLayout.compactMinimumMeasuredWidth
        }

        return normalized >= minimum
    }
}

struct OverlayMeasurementCache {
    private var heights: [OverlayLayoutState: CGFloat] = [:]
    private var widths: [OverlayLayoutState: CGFloat] = [:]

    mutating func applyHeight(_ measured: CGFloat, for state: OverlayLayoutState) -> Bool {
        guard OverlayMeasurementValidation.isValid(measured, for: state, axis: .height) else { return false }
        let current = heights[state] ?? 0
        guard OverlayLayout.shouldApplyMeasuredSize(current: current, measured: measured) else { return false }

        heights[state] = OverlayLayout.normalizedSize(measured)
        return true
    }

    mutating func applyHeight(_ measured: CGFloat, for mode: OverlayDisplayMode) -> Bool {
        applyHeight(measured, for: .defaultState(for: mode))
    }

    mutating func applyWidth(_ measured: CGFloat, for state: OverlayLayoutState) -> Bool {
        guard state.mode == .compact else { return false }
        guard OverlayMeasurementValidation.isValid(measured, for: state, axis: .width) else { return false }
        let current = widths[state] ?? 0
        guard OverlayLayout.shouldApplyMeasuredSize(current: current, measured: measured) else { return false }

        widths[state] = OverlayLayout.normalizedSize(measured)
        return true
    }

    mutating func applyWidth(_ measured: CGFloat, for mode: OverlayDisplayMode) -> Bool {
        applyWidth(measured, for: .defaultState(for: mode))
    }

    func hasMeasuredSize(for state: OverlayLayoutState) -> Bool {
        switch state.mode {
        case .standard:
            (heights[state] ?? 0) > 0
        case .compact:
            (heights[state] ?? 0) > 0 && (widths[state] ?? 0) > 0
        }
    }

    func hasMeasuredSize(for mode: OverlayDisplayMode) -> Bool {
        hasMeasuredSize(for: .defaultState(for: mode))
    }

    func size(for state: OverlayLayoutState) -> CGSize {
        switch state.mode {
        case .standard:
            let height = (heights[state] ?? 0) > 0 ? heights[state]! : OverlayLayout.standardFallbackHeight
            return CGSize(width: OverlayLayout.standardWidth, height: height)
        case .compact:
            let width = (widths[state] ?? 0) > 0 ? widths[state]! : OverlayLayout.compactFallbackWidth
            let height = (heights[state] ?? 0) > 0 ? heights[state]! : OverlayLayout.compactFallbackHeight
            return CGSize(width: width, height: height)
        }
    }

    func size(for mode: OverlayDisplayMode) -> CGSize {
        size(for: .defaultState(for: mode))
    }
}

struct OverlayTransitionState {
    private(set) var presentedState: OverlayLayoutState
    private(set) var pendingState: OverlayLayoutState?
    private var pendingHeightSeen = false
    private var pendingWidthSeen = false

    init() {
        self.init(initialState: .defaultState(for: .standard))
    }

    init(initialState: OverlayLayoutState) {
        self.presentedState = initialState
    }

    init(initialMode: OverlayDisplayMode) {
        self.init(initialState: .defaultState(for: initialMode))
    }

    mutating func prepare(for targetState: OverlayLayoutState) {
        if targetState == presentedState {
            pendingState = nil
            pendingHeightSeen = false
            pendingWidthSeen = false
            return
        }

        guard pendingState != targetState else { return }
        pendingState = targetState
        pendingHeightSeen = false
        pendingWidthSeen = false
    }

    mutating func prepare(for targetMode: OverlayDisplayMode) {
        prepare(for: .defaultState(for: targetMode))
    }

    mutating func registerMeasurement(for state: OverlayLayoutState, axis: OverlayMeasurementAxis) -> Bool {
        guard pendingState == state else { return false }

        switch axis {
        case .height:
            pendingHeightSeen = true
        case .width:
            pendingWidthSeen = true
        }

        let transitionReady: Bool
        switch state.mode {
        case .standard:
            transitionReady = pendingHeightSeen
        case .compact:
            transitionReady = pendingHeightSeen && pendingWidthSeen
        }

        guard transitionReady else { return false }
        presentedState = state
        pendingState = nil
        pendingHeightSeen = false
        pendingWidthSeen = false
        return true
    }

    mutating func registerMeasurement(for mode: OverlayDisplayMode, axis: OverlayMeasurementAxis) -> Bool {
        registerMeasurement(for: .defaultState(for: mode), axis: axis)
    }

    var presentedMode: OverlayDisplayMode {
        presentedState.mode
    }

    var pendingMode: OverlayDisplayMode? {
        pendingState?.mode
    }

    var isAwaitingMeasurement: Bool {
        pendingState != nil
    }
}

enum OverlayMeasurementRouter {
    static func handle(
        value: CGFloat,
        state: OverlayLayoutState,
        axis: OverlayMeasurementAxis,
        cache: inout OverlayMeasurementCache,
        transitionState: inout OverlayTransitionState
    ) -> Bool {
        guard OverlayMeasurementValidation.isValid(value, for: state, axis: axis) else { return false }

        let sizeChanged: Bool
        switch axis {
        case .height:
            sizeChanged = cache.applyHeight(value, for: state)
        case .width:
            sizeChanged = cache.applyWidth(value, for: state)
        }

        let transitionCompleted = transitionState.registerMeasurement(for: state, axis: axis)
        return transitionCompleted
            || (sizeChanged && !transitionState.isAwaitingMeasurement && transitionState.presentedState == state)
    }

    static func handle(
        value: CGFloat,
        mode: OverlayDisplayMode,
        axis: OverlayMeasurementAxis,
        cache: inout OverlayMeasurementCache,
        transitionState: inout OverlayTransitionState
    ) -> Bool {
        handle(
            value: value,
            state: .defaultState(for: mode),
            axis: axis,
            cache: &cache,
            transitionState: &transitionState
        )
    }
}

enum OverlayPresentationDecision {
    static func shouldHoldCurrentFrame(
        transitionState: OverlayTransitionState,
        cache: OverlayMeasurementCache,
        targetState: OverlayLayoutState
    ) -> Bool {
        transitionState.isAwaitingMeasurement && !cache.hasMeasuredSize(for: targetState)
    }

    static func shouldHoldCurrentFrame(
        transitionState: OverlayTransitionState,
        cache: OverlayMeasurementCache,
        targetMode: OverlayDisplayMode
    ) -> Bool {
        shouldHoldCurrentFrame(
            transitionState: transitionState,
            cache: cache,
            targetState: .defaultState(for: targetMode)
        )
    }
}

private struct OverlayMeasurement: Equatable {
    let state: OverlayLayoutState
    let value: CGFloat
}

private struct ContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: OverlayMeasurement?
    static func reduce(value: inout OverlayMeasurement?, nextValue: () -> OverlayMeasurement?) {
        value = nextValue() ?? value
    }
}

private struct ContentWidthKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: OverlayMeasurement?
    static func reduce(value: inout OverlayMeasurement?, nextValue: () -> OverlayMeasurement?) {
        value = nextValue() ?? value
    }
}

struct OverlayContent: View {
    @Bindable var manager: CalendarManager
    var onContentHeight: ((OverlayLayoutState, CGFloat) -> Void)?
    var onContentWidth: ((OverlayLayoutState, CGFloat) -> Void)?

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    private var currentLayoutState: OverlayLayoutState {
        OverlayLayoutState(model: manager.model)
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
        .onPreferenceChange(ContentHeightKey.self) { measurement in
            guard let measurement else { return }
            onContentHeight?(measurement.state, measurement.value)
        }
        .onPreferenceChange(ContentWidthKey.self) { measurement in
            guard let measurement else { return }
            onContentWidth?(measurement.state, measurement.value)
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
        .frame(width: OverlayLayout.standardWidth)
        .background(GeometryReader { geo in
            Color.clear.preference(
                key: ContentHeightKey.self,
                value: OverlayMeasurement(state: currentLayoutState, value: geo.size.height)
            )
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
                .preference(
                    key: ContentHeightKey.self,
                    value: OverlayMeasurement(state: currentLayoutState, value: geo.size.height)
                )
                .preference(
                    key: ContentWidthKey.self,
                    value: OverlayMeasurement(state: currentLayoutState, value: geo.size.width)
                )
        })
        .frame(maxWidth: .infinity, alignment: .leading)
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
