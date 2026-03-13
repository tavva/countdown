// ABOUTME: App entry point for the meeting countdown menu bar app.
// ABOUTME: Configures MenuBarExtra with .window style, delegating state to AppDelegate.

import SwiftUI

@main
struct CountdownApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            SettingsView(manager: appDelegate.calendarManager, updateManager: appDelegate.updateManager)
        } label: {
            Image(systemName: "circle.fill")
                .foregroundStyle(appDelegate.calendarManager.model.shouldShowOverlay ? .red : .gray)
        }
        .menuBarExtraStyle(.window)
    }
}
