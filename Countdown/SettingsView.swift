// ABOUTME: Menu bar popover showing event status, Google account controls, and event filter.
// ABOUTME: Provides connect/disconnect for Google Calendar and a meetings-only toggle.

import SwiftUI

struct SettingsView: View {
    @Bindable var manager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusSection

            Divider()

            accountSection

            Divider()

            filterSection

            Spacer()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 280, height: 260)
    }

    private var meetingsOnlyBinding: Binding<Bool> {
        Binding(
            get: { manager.model.meetingsOnly },
            set: { manager.model.meetingsOnly = $0 }
        )
    }

    @ViewBuilder
    private var statusSection: some View {
        if let event = manager.model.nextEvent {
            Text("Next: \(event.summary) in \(manager.model.minutesRemaining) min")
                .font(.headline)
        } else if manager.isSignedIn {
            Text("No upcoming events")
                .font(.headline)
                .foregroundStyle(.secondary)
        } else {
            Text("Not connected")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Google Account")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if manager.config == nil {
                Text("Add your Google OAuth credentials to Config.plist to get started.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if manager.isSignedIn {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected")
                    Spacer()
                    Button("Disconnect") {
                        Task { await manager.signOut() }
                    }
                }
            } else {
                Button("Connect Google Account") {
                    Task { await manager.signIn() }
                }
                .buttonStyle(.borderedProminent)
            }

            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show countdown for")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("", selection: meetingsOnlyBinding) {
                Text("All events").tag(false)
                Text("Meetings only").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }
}
