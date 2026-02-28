// ABOUTME: Menu bar popover showing event status, Google account controls, and event filter.
// ABOUTME: Provides connect/disconnect for Google Calendar, a meetings-only toggle, and calendar selection.

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

            if manager.isSignedIn && !manager.calendars.isEmpty {
                Divider()
                calendarsSection
            }

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
        .frame(minWidth: 280, maxWidth: 280, minHeight: 260)
    }

    private var meetingsOnlyBinding: Binding<Bool> {
        Binding(
            get: { manager.model.meetingsOnly },
            set: { manager.setMeetingsOnly($0) }
        )
    }

    private var alwaysShowCircleBinding: Binding<Bool> {
        Binding(
            get: { manager.model.alwaysShowCircle },
            set: { manager.setAlwaysShowCircle($0) }
        )
    }

    private var showEventDetailsBinding: Binding<Bool> {
        Binding(
            get: { manager.model.showingEventDetails },
            set: { manager.model.showingEventDetails = $0 }
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

            Text("Show circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Picker("", selection: alwaysShowCircleBinding) {
                Text("Always").tag(true)
                Text("Only before events").tag(false)
            }
            .pickerStyle(.segmented)

            Text("Event details")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Picker("", selection: showEventDetailsBinding) {
                Text("Show").tag(true)
                Text("Hide").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var calendarsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendars")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(manager.calendars) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(hex: calendar.backgroundColor))
                                .frame(width: 10, height: 10)
                            Text(calendar.summary)
                                .font(.body)
                                .lineLimit(1)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { manager.isCalendarEnabled(calendar.id) },
                                set: { _ in manager.toggleCalendar(calendar.id) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }
                }
            }
            .frame(maxHeight: 120)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
