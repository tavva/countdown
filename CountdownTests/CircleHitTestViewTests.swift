// ABOUTME: Tests that the circle hit-test logic passes through clicks outside the circle.
// ABOUTME: Verifies that only clicks within the circle radius are handled by the panel.

import Testing
import Foundation
@testable import Countdown

@Suite("CircleHitTest")
struct CircleHitTestTests {
    // Panel is 200x120, circle is top-aligned, 55px from top.
    // In AppKit coords (origin bottom-left), circle centre is at (100, 65).
    private let normalSize = CGSize(width: 200, height: 120)
    // When event details are showing, panel is 200x190.
    // Circle centre stays 55px from top → (100, 135) in AppKit coords.
    private let expandedSize = CGSize(width: 200, height: 190)

    @Test func clickAtCircleCentreIsInside() {
        #expect(CircleHitTest.isInsideCircle(point: CGPoint(x: 100, y: 65), viewSize: normalSize))
    }

    @Test func clickInsideCircleRadiusIsInside() {
        // 30px from centre — well within 45px radius
        #expect(CircleHitTest.isInsideCircle(point: CGPoint(x: 130, y: 65), viewSize: normalSize))
    }

    @Test func clickAtCircleEdgeIsInside() {
        // Exactly 45px from centre
        #expect(CircleHitTest.isInsideCircle(point: CGPoint(x: 145, y: 65), viewSize: normalSize))
    }

    @Test func clickOutsideCircleIsOutside() {
        // Bottom-left corner — far from circle
        #expect(!CircleHitTest.isInsideCircle(point: CGPoint(x: 10, y: 10), viewSize: normalSize))
    }

    @Test func clickJustOutsideCircleIsOutside() {
        // 50px from centre — outside 45px radius
        #expect(!CircleHitTest.isInsideCircle(point: CGPoint(x: 150, y: 65), viewSize: normalSize))
    }

    @Test func clickInTopCornerIsOutside() {
        #expect(!CircleHitTest.isInsideCircle(point: CGPoint(x: 0, y: 120), viewSize: normalSize))
    }

    @Test func clickInDetailsAreaWithExpandedPanelIsOutside() {
        // Circle centre at (100, 135) in expanded mode.
        // Click in the bottom area (event details region) — should be outside.
        #expect(!CircleHitTest.isInsideCircle(point: CGPoint(x: 100, y: 20), viewSize: expandedSize))
    }

    @Test func clickOnCircleWithExpandedPanelIsInside() {
        // Circle centre at (100, 135)
        #expect(CircleHitTest.isInsideCircle(point: CGPoint(x: 100, y: 135), viewSize: expandedSize))
    }
}
