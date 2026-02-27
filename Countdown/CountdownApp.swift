// ABOUTME: App entry point for the meeting countdown menu bar app.
// ABOUTME: Configures MenuBarExtra with .window style and wires up AppDelegate.

import SwiftUI

@main
struct CountdownApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var manager: CalendarManager

    init() {
        let mgr = CalendarManager()
        mgr.config = Config.load()
        _manager = State(initialValue: mgr)
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsView(manager: manager)
                .onAppear {
                    appDelegate.setupOverlay(manager: manager)
                    if manager.isSignedIn {
                        manager.startPolling()
                    }
                }
        } label: {
            Image(systemName: "circle.fill")
                .foregroundStyle(manager.model.shouldShowOverlay ? .red : .gray)
        }
        .menuBarExtraStyle(.window)
    }
}
