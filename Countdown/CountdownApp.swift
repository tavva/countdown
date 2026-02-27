// ABOUTME: App entry point for the meeting countdown menu bar app.
// ABOUTME: Configures MenuBarExtra with .window style and wires up AppDelegate.

import SwiftUI

@main
struct CountdownApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            Text("Countdown")
                .frame(width: 280, height: 200)
                .padding()
        } label: {
            Image(systemName: "circle.fill")
                .foregroundStyle(.gray)
        }
        .menuBarExtraStyle(.window)
    }
}
