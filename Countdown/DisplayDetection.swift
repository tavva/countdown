// ABOUTME: Detects whether any connected screen is a non-built-in (external) display.
// ABOUTME: Required to correctly handle clamshell mode where only an external display is active.

import AppKit
import CoreGraphics

enum DisplayDetection {
    /// Pure function for testability — takes an array of "is built-in" flags.
    static func hasExternalDisplay(isBuiltinFlags: [Bool]) -> Bool {
        isBuiltinFlags.contains(false)
    }

    /// Queries NSScreen and CGDisplay to determine if any connected screen is external.
    @MainActor
    static func hasExternalDisplay() -> Bool {
        let flags = NSScreen.screens.map { screen -> Bool in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            return CGDisplayIsBuiltin(displayID) != 0
        }
        return hasExternalDisplay(isBuiltinFlags: flags)
    }
}
