// ABOUTME: Tests for the external display detection helper.
// ABOUTME: Verifies the pure logic that determines if any screen is non-built-in.

import Testing
import Foundation
@testable import Countdown

@Suite("DisplayDetection")
struct DisplayDetectionTests {
    @Test func noScreensMeansNoExternal() {
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: []) == false)
    }

    @Test func onlyBuiltinMeansNoExternal() {
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: [true]) == false)
    }

    @Test func onlyExternalMeansHasExternal() {
        // Clamshell mode: laptop lid closed, only external connected
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: [false]) == true)
    }

    @Test func builtinPlusExternalMeansHasExternal() {
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: [true, false]) == true)
    }

    @Test func multipleExternalsMeansHasExternal() {
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: [true, false, false]) == true)
    }
}
