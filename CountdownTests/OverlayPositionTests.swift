// ABOUTME: Tests for overlay panel position persistence and screen visibility.
// ABOUTME: Verifies saving, restoring, clearing, and off-screen detection.

import Testing
import Foundation
@testable import Countdown

@Suite("OverlayPosition", .serialized)
struct OverlayPositionTests {
    private let _snapshot = DefaultsSnapshot(keys: ["overlayPosition"])

    @Test func restoreReturnsNilWhenNoSavedPosition() {
        UserDefaults.standard.removeObject(forKey: "overlayPosition")
        #expect(OverlayPosition.restore() == nil)
    }

    @Test func saveAndRestoreRoundTrips() {
        let origin = CGPoint(x: 123.5, y: 456.0)
        OverlayPosition.save(origin)

        let restored = OverlayPosition.restore()
        #expect(restored != nil)
        #expect(restored!.x == 123.5)
        #expect(restored!.y == 456.0)
    }

    @Test func clearRemovesSavedPosition() {
        OverlayPosition.save(CGPoint(x: 10, y: 20))
        OverlayPosition.clear()
        #expect(OverlayPosition.restore() == nil)
    }

    // MARK: - Screen visibility

    @Test func positionInsideSingleScreenIsVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        #expect(OverlayPosition.isVisible(origin: CGPoint(x: 100, y: 100), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionOffRightEdgeIsNotVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        #expect(!OverlayPosition.isVisible(origin: CGPoint(x: 2000, y: 100), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionOnSecondScreenIsVisible() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 2560, height: 1440),
        ]
        #expect(OverlayPosition.isVisible(origin: CGPoint(x: 2000, y: 100), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionBelowAllScreensIsNotVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        #expect(!OverlayPosition.isVisible(origin: CGPoint(x: 100, y: -200), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionWithNoScreensIsNotVisible() {
        let screens: [CGRect] = []
        #expect(!OverlayPosition.isVisible(origin: CGPoint(x: 100, y: 100), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionPartiallyVisibleIsVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        // Panel at x: 1800 — only 120px of 200px width visible, but centre is on screen
        #expect(OverlayPosition.isVisible(origin: CGPoint(x: 1800, y: 500), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionWithOnlyCentreOffScreenIsNotVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        // Panel centre at x: 2000 — off screen
        #expect(!OverlayPosition.isVisible(origin: CGPoint(x: 1900, y: 500), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    // MARK: - Screen clamping

    @Test func clampReturnsNilWhenAlreadyOnScreen() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        let result = OverlayPosition.clampedOrigin(
            origin: CGPoint(x: 100, y: 100),
            panelSize: CGSize(width: 200, height: 120),
            screenFrames: screens
        )
        #expect(result == nil)
    }

    @Test func clampNudgesRightOverflowBackOnScreen() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        // Panel origin at x:1900, centre at x:2000 — off the right edge
        let result = OverlayPosition.clampedOrigin(
            origin: CGPoint(x: 1900, y: 500),
            panelSize: CGSize(width: 200, height: 120),
            screenFrames: screens
        )
        #expect(result != nil)
        // Centre should be clamped to screen edge, so origin.x = 1920 - 100 = 1820
        #expect(result!.x == 1820)
        #expect(result!.y == 500)
    }

    @Test func clampNudgesBottomOverflowBackOnScreen() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        // Panel origin at y:-100, centre at y:-40 — below screen bottom (macOS y=0 is bottom)
        let result = OverlayPosition.clampedOrigin(
            origin: CGPoint(x: 100, y: -100),
            panelSize: CGSize(width: 200, height: 120),
            screenFrames: screens
        )
        #expect(result != nil)
        #expect(result!.x == 100)
        // Centre clamped to y=0, so origin.y = 0 - 60 = -60
        #expect(result!.y == -60)
    }

    @Test func clampNudgesToNearestScreen() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 2560, height: 1440),
        ]
        // Panel centre off the right edge of screen 2 (x: 4480 + 100 = 4580)
        let result = OverlayPosition.clampedOrigin(
            origin: CGPoint(x: 4480, y: 500),
            panelSize: CGSize(width: 200, height: 120),
            screenFrames: screens
        )
        #expect(result != nil)
        // Should clamp to screen 2's right edge: 1920 + 2560 = 4480, centre at 4480, origin = 4380
        #expect(result!.x == 4380)
    }

    @Test func clampReturnsNilWithNoScreens() {
        let result = OverlayPosition.clampedOrigin(
            origin: CGPoint(x: 100, y: 100),
            panelSize: CGSize(width: 200, height: 120),
            screenFrames: []
        )
        #expect(result == nil)
    }

    @Test func clampHandlesCornerOverflow() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        // Both x and y off-screen (bottom-right corner)
        let result = OverlayPosition.clampedOrigin(
            origin: CGPoint(x: 1900, y: -100),
            panelSize: CGSize(width: 200, height: 120),
            screenFrames: screens
        )
        #expect(result != nil)
        #expect(result!.x == 1820)
        #expect(result!.y == -60)
    }
}

@Suite("OverlayLayout")
struct OverlayLayoutTests {
    @Test func roundsMeasuredHeightUpToWholePoints() {
        #expect(OverlayLayout.normalizedSize(189.01) == 190)
        #expect(OverlayLayout.normalizedSize(190.0) == 190)
    }

    @Test func ignoresJitterThatRoundsToCurrentHeight() {
        #expect(!OverlayLayout.shouldApplyMeasuredSize(current: 190, measured: 189.1))
        #expect(!OverlayLayout.shouldApplyMeasuredSize(current: 190, measured: 190.0))
    }

    @Test func appliesHeightWhenRoundedValueChanges() {
        #expect(OverlayLayout.shouldApplyMeasuredSize(current: 190, measured: 190.2))
        #expect(OverlayLayout.shouldApplyMeasuredSize(current: 190, measured: 191.0))
    }
}

@Suite("OverlayFramePlacement")
struct OverlayFramePlacementTests {
    @Test func restoredOriginIsPreservedOnFirstResize() {
        let savedOrigin = CGPoint(x: 38, y: 1031)
        var placement = OverlayFramePlacement(
            initialFrame: CGRect(x: savedOrigin.x, y: savedOrigin.y, width: 200, height: 120),
            restoredOrigin: savedOrigin
        )

        let compactFrame = placement.frame(for: CGSize(width: 44, height: 36))
        #expect(compactFrame.origin == savedOrigin)

        let detailsFrame = placement.frame(for: CGSize(width: 188, height: 60))
        #expect(detailsFrame.origin == CGPoint(x: 38, y: 1007))
    }

    @Test func liveFrameWithoutRestoredOriginKeepsCurrentTopEdge() {
        var placement = OverlayFramePlacement(
            initialFrame: CGRect(x: 20, y: 900, width: 200, height: 120),
            restoredOrigin: nil
        )

        let compactFrame = placement.frame(for: CGSize(width: 44, height: 36))

        #expect(compactFrame.origin == CGPoint(x: 20, y: 984))
    }
}

@Suite("OverlayMeasurementCache")
struct OverlayMeasurementCacheTests {
    @Test func keepsMeasurementsSeparatePerMode() {
        var cache = OverlayMeasurementCache()

        let appliedStandardHeight = cache.applyHeight(189.1, for: .standard)
        let appliedCompactHeight = cache.applyHeight(35.2, for: .compact)
        let appliedCompactWidth = cache.applyWidth(127.1, for: .compact)

        #expect(appliedStandardHeight)
        #expect(appliedCompactHeight)
        #expect(appliedCompactWidth)

        #expect(cache.size(for: .standard) == CGSize(width: 200, height: 190))
        #expect(cache.size(for: .compact) == CGSize(width: 128, height: 36))
    }

    @Test func usesFallbackSizesUntilModeIsMeasured() {
        let cache = OverlayMeasurementCache()

        #expect(cache.size(for: .standard) == CGSize(width: 200, height: 200))
        #expect(cache.size(for: .compact) == CGSize(width: 400, height: 36))
    }

    @Test func ignoresRoundedJitterWithinEachMode() {
        var cache = OverlayMeasurementCache()

        let appliedStandardHeight = cache.applyHeight(189.1, for: .standard)
        let ignoredStandardJitter = cache.applyHeight(189.9, for: .standard)
        let appliedCompactWidth = cache.applyWidth(127.1, for: .compact)
        let ignoredCompactJitter = cache.applyWidth(127.9, for: .compact)

        #expect(appliedStandardHeight)
        #expect(!ignoredStandardJitter)
        #expect(appliedCompactWidth)
        #expect(!ignoredCompactJitter)
    }

    @Test func reportsWhenEachModeHasEnoughMeasurements() {
        var cache = OverlayMeasurementCache()

        #expect(!cache.hasMeasuredSize(for: .standard))
        #expect(!cache.hasMeasuredSize(for: .compact))

        _ = cache.applyHeight(189.1, for: .standard)
        #expect(cache.hasMeasuredSize(for: .standard))
        #expect(!cache.hasMeasuredSize(for: .compact))

        _ = cache.applyHeight(35.2, for: .compact)
        #expect(!cache.hasMeasuredSize(for: .compact))

        _ = cache.applyWidth(127.1, for: .compact)
        #expect(cache.hasMeasuredSize(for: .compact))
    }

    @Test func ignoresUndersizedTransientMeasurements() {
        var cache = OverlayMeasurementCache()

        let ignoredStandardHeight = cache.applyHeight(1, for: .standard)
        let ignoredCompactHeight = cache.applyHeight(1, for: .compact)
        let ignoredCompactWidth = cache.applyWidth(1, for: .compact)

        #expect(!ignoredStandardHeight)
        #expect(!ignoredCompactHeight)
        #expect(!ignoredCompactWidth)
        #expect(!cache.hasMeasuredSize(for: .standard))
        #expect(!cache.hasMeasuredSize(for: .compact))
    }
}

@Suite("OverlayTransitionState")
struct OverlayTransitionStateTests {
    @Test func compactTransitionWaitsForBothMeasurements() {
        var state = OverlayTransitionState()

        state.prepare(for: .compact)
        #expect(state.isAwaitingMeasurement)

        let completedAfterHeight = state.registerMeasurement(for: .compact, axis: .height)
        #expect(!completedAfterHeight)
        #expect(state.isAwaitingMeasurement)

        let completedAfterWidth = state.registerMeasurement(for: .compact, axis: .width)
        #expect(completedAfterWidth)
        #expect(!state.isAwaitingMeasurement)
        #expect(state.presentedMode == .compact)
    }

    @Test func standardTransitionCompletesAfterHeightMeasurement() {
        var state = OverlayTransitionState(initialMode: .compact)

        state.prepare(for: .standard)
        #expect(state.isAwaitingMeasurement)

        let completed = state.registerMeasurement(for: .standard, axis: .height)
        #expect(completed)
        #expect(!state.isAwaitingMeasurement)
        #expect(state.presentedMode == .standard)
    }

    @Test func revertingToPresentedModeCancelsPendingTransition() {
        var state = OverlayTransitionState()

        state.prepare(for: .compact)
        #expect(state.isAwaitingMeasurement)

        state.prepare(for: .standard)
        #expect(!state.isAwaitingMeasurement)
        #expect(state.presentedMode == .standard)
    }
}

@Suite("OverlayPresentationDecision")
struct OverlayPresentationDecisionTests {
    @Test func holdsCurrentFrameWhenAwaitingFirstMeasurementForTargetMode() {
        var transition = OverlayTransitionState()
        let cache = OverlayMeasurementCache()

        transition.prepare(for: .compact)

        #expect(OverlayPresentationDecision.shouldHoldCurrentFrame(
            transitionState: transition,
            cache: cache,
            targetMode: .compact
        ))
    }

    @Test func usesCachedFrameWhileAwaitingFreshMeasurement() {
        var transition = OverlayTransitionState()
        var cache = OverlayMeasurementCache()

        _ = cache.applyHeight(188.2, for: .standard)
        transition.prepare(for: .standard)

        #expect(!OverlayPresentationDecision.shouldHoldCurrentFrame(
            transitionState: transition,
            cache: cache,
            targetMode: .standard
        ))
    }
}

@Suite("OverlayMeasurementRouter")
struct OverlayMeasurementRouterTests {
    @Test func ignoresUndersizedCompactMeasurementsDuringTransition() {
        var cache = OverlayMeasurementCache()
        var transition = OverlayTransitionState()

        transition.prepare(for: .compact)

        let refreshAfterTinyHeight = OverlayMeasurementRouter.handle(
            value: 1,
            mode: .compact,
            axis: .height,
            cache: &cache,
            transitionState: &transition
        )
        let refreshAfterTinyWidth = OverlayMeasurementRouter.handle(
            value: 1,
            mode: .compact,
            axis: .width,
            cache: &cache,
            transitionState: &transition
        )

        #expect(!refreshAfterTinyHeight)
        #expect(!refreshAfterTinyWidth)
        #expect(transition.isAwaitingMeasurement)
        #expect(!cache.hasMeasuredSize(for: .compact))
    }

    @Test func completesCompactTransitionAfterPlausibleMeasurements() {
        var cache = OverlayMeasurementCache()
        var transition = OverlayTransitionState()

        transition.prepare(for: .compact)

        let refreshAfterHeight = OverlayMeasurementRouter.handle(
            value: 36,
            mode: .compact,
            axis: .height,
            cache: &cache,
            transitionState: &transition
        )
        let refreshAfterWidth = OverlayMeasurementRouter.handle(
            value: 80,
            mode: .compact,
            axis: .width,
            cache: &cache,
            transitionState: &transition
        )

        #expect(!refreshAfterHeight)
        #expect(refreshAfterWidth)
        #expect(!transition.isAwaitingMeasurement)
        #expect(transition.presentedMode == .compact)
        #expect(cache.size(for: .compact) == CGSize(width: 80, height: 36))
    }
}

@Suite("OverlayLayoutStateCaching")
struct OverlayLayoutStateCachingTests {
    @Test func standardDetailsVisibilityKeepsSeparateHeights() {
        var cache = OverlayMeasurementCache()
        let detailsHidden = OverlayLayoutState(mode: .standard, showsEventDetails: false, showsCompactMinutes: false)
        let detailsShown = OverlayLayoutState(mode: .standard, showsEventDetails: true, showsCompactMinutes: false)

        _ = cache.applyHeight(109.1, for: detailsHidden)
        _ = cache.applyHeight(188.2, for: detailsShown)

        #expect(cache.size(for: detailsHidden) == CGSize(width: 200, height: 110))
        #expect(cache.size(for: detailsShown) == CGSize(width: 200, height: 189))
    }

    @Test func compactDetailsVisibilityKeepsSeparateWidths() {
        var cache = OverlayMeasurementCache()
        let detailsHidden = OverlayLayoutState(mode: .compact, showsEventDetails: false, showsCompactMinutes: true)
        let detailsShown = OverlayLayoutState(mode: .compact, showsEventDetails: true, showsCompactMinutes: true)

        _ = cache.applyHeight(35.2, for: detailsHidden)
        _ = cache.applyWidth(79.1, for: detailsHidden)
        _ = cache.applyHeight(35.2, for: detailsShown)
        _ = cache.applyWidth(187.4, for: detailsShown)

        #expect(cache.size(for: detailsHidden) == CGSize(width: 80, height: 36))
        #expect(cache.size(for: detailsShown) == CGSize(width: 188, height: 36))
    }

    @Test func compactEmptyMessageKeepsSeparateWidthFromDotOnly() {
        var cache = OverlayMeasurementCache()
        let dotOnly = OverlayLayoutState(mode: .compact, showsEventDetails: false, showsCompactMinutes: false, showsEmptyMessage: false)
        let emptyMessage = OverlayLayoutState(mode: .compact, showsEventDetails: false, showsCompactMinutes: false, showsEmptyMessage: true)

        _ = cache.applyHeight(35.2, for: dotOnly)
        _ = cache.applyWidth(44.0, for: dotOnly)
        _ = cache.applyHeight(35.2, for: emptyMessage)
        _ = cache.applyWidth(180.0, for: emptyMessage)

        #expect(cache.size(for: dotOnly) == CGSize(width: 44, height: 36))
        #expect(cache.size(for: emptyMessage) == CGSize(width: 180, height: 36))
    }
}

@Suite("OverlayLayoutStateTransition")
struct OverlayLayoutStateTransitionTests {
    @Test func detailsToggleWithinStandardModeStartsPendingTransition() {
        let detailsHidden = OverlayLayoutState(mode: .standard, showsEventDetails: false, showsCompactMinutes: false)
        let detailsShown = OverlayLayoutState(mode: .standard, showsEventDetails: true, showsCompactMinutes: false)
        var transition = OverlayTransitionState(initialState: detailsHidden)

        transition.prepare(for: detailsShown)

        #expect(transition.isAwaitingMeasurement)

        let completed = transition.registerMeasurement(for: detailsShown, axis: .height)
        #expect(completed)
        #expect(transition.presentedState == detailsShown)
    }

    @Test func compactLoadingToIdleWithEmptyMessageStartsTransition() {
        let loading = OverlayLayoutState(mode: .compact, showsEventDetails: false, showsCompactMinutes: false, showsEmptyMessage: false)
        let idle = OverlayLayoutState(mode: .compact, showsEventDetails: false, showsCompactMinutes: false, showsEmptyMessage: true)
        var transition = OverlayTransitionState(initialState: loading)

        transition.prepare(for: idle)

        #expect(transition.isAwaitingMeasurement)
        #expect(loading != idle)
    }
}

@Suite("OverlayLayoutState construction", .serialized)
struct OverlayLayoutStateModelTests {
    private let _snapshot = DefaultsSnapshot(keys: [
        "meetingsOnly", "showingEventDetails", "compactMode",
        "hideDeclinedEvents",
    ])

    @Test func compactIdleWithDetailsShowsEmptyMessage() {
        let model = CountdownModel()
        model.compactMode = true
        model.showingEventDetails = true
        model.setEvents([])
        model.updateState()

        let state = OverlayLayoutState(model: model)

        #expect(state.mode == .compact)
        #expect(state.showsEmptyMessage == true)
    }

    @Test func compactLoadingDoesNotShowEmptyMessage() {
        let model = CountdownModel()
        model.compactMode = true
        model.showingEventDetails = true
        // Model starts in loading state, don't call setEvents

        let state = OverlayLayoutState(model: model)

        #expect(state.mode == .compact)
        #expect(state.showsEmptyMessage == false)
    }

    @Test func compactIdleWithDetailsOffDoesNotShowEmptyMessage() {
        let model = CountdownModel()
        model.compactMode = true
        model.showingEventDetails = false
        model.setEvents([])
        model.updateState()

        let state = OverlayLayoutState(model: model)

        #expect(state.mode == .compact)
        #expect(state.showsEmptyMessage == false)
    }
}
