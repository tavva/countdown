// ABOUTME: Menu bar pop-up with the app's settings, split into Circle, Events, Calendars and General tabs.
// ABOUTME: Signed out, it shows the Google sign-in button (or the Config.plist notice) instead of the tabs.

import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var manager: CalendarManager
    let updateManager: UpdateManager

    @State private var selectedTab = SettingsTab.restore()
    /// Calendar IDs in display order: enabled calendars first. Recomputed when
    /// the Calendars tab appears or the calendar list changes, not on every
    /// toggle, so a row doesn't jump away from the pointer when it's clicked.
    @State private var calendarOrder: [String] = []

    private static let width: CGFloat = 340
    private static let signedInHeight: CGFloat = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            banners

            if manager.isSignedIn {
                tabBar
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                signedOutContent
            }

            footer
        }
        .frame(width: Self.width, height: manager.isSignedIn ? Self.signedInHeight : nil, alignment: .top)
        .onChange(of: selectedTab) { _, tab in
            tab.save()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Countdown")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(manager.isSignedIn ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text(manager.isSignedIn ? "Google Calendar connected" : "Not connected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Banners

    @ViewBuilder
    private var banners: some View {
        if let hiddenUntil = manager.model.hiddenUntil {
            hiddenBanner(until: hiddenUntil)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }

        if let error = manager.errorMessage {
            errorBanner(error)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private var setupNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))
            Text("Add your Google OAuth credentials to Config.plist to get started.")
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func hiddenBanner(until date: Date) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "eye.slash")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 13))
            Text(HideUntilText.hiddenUntil(date))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Show now") {
                manager.model.showNow()
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.16))
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let isSelected = tab == selectedTab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 15))
                    .frame(height: 18)
                Text(tab.title)
                    .font(.system(size: 11))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 7)
            .padding(.bottom, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.primary.opacity(0.1) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .circle: circleTab
        case .events: eventsTab
        case .calendars: calendarsTab
        case .general: generalTab
        }
    }

    // MARK: - Circle tab

    private var circleTab: some View {
        card {
            settingRow("Size") {
                Picker("Size", selection: sizeModeBinding) {
                    Text("Standard").tag(SizeMode.standard)
                    Text("Compact").tag(SizeMode.compact)
                    Text("Auto").tag(SizeMode.auto)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            rowCaption("Auto is compact on the built-in display, and standard when an external display is connected.")
            rowSeparator
            switchRow("Show event details", isOn: showEventDetailsBinding)
            rowSeparator
            switchRow("Show time left in meeting", isOn: showMeetingProgressBinding)
            rowSeparator
            switchRow("Move when displays change", isOn: autoRepositionBinding)

            if manager.model.autoReposition {
                HStack(spacing: 12) {
                    Text("To corner")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    ScreenCornerPicker(selection: repositionCornerBinding)
                }
                .frame(minHeight: 40)
                .padding(.leading, 28)
                .padding(.trailing, 12)
                .padding(.bottom, 6)
                .transition(.opacity)
            }
        }
        .animation(.default, value: manager.model.autoReposition)
        .padding(.horizontal, 12)
    }

    // MARK: - Events tab

    private var eventsTab: some View {
        card {
            settingRow("Count down to") {
                Picker("Count down to", selection: meetingsOnlyBinding) {
                    Text("All events").tag(false)
                    Text("Meetings only").tag(true)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            rowCaption("Meetings are events with at least one other guest.")
            rowSeparator
            switchRow("Skip declined & cancelled", isOn: hideDeclinedBinding)
            rowSeparator
            switchRow("Skip tasks & birthdays", isOn: hideTasksAndBirthdaysBinding)
            rowSeparator
            switchRow("Skip focus time", isOn: hideFocusTimeBinding)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Calendars tab

    private var calendarsTab: some View {
        card {
            if manager.calendars.isEmpty {
                Text("No calendars found.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        let calendars = orderedCalendars
                        ForEach(Array(calendars.enumerated()), id: \.element.id) { index, calendar in
                            calendarRow(calendar)
                            if index < calendars.count - 1 {
                                rowSeparator
                            }
                        }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onAppear(perform: sortCalendars)
        .onChange(of: manager.calendars.map(\.id)) { sortCalendars() }
    }

    private func calendarRow(_ calendar: CalendarInfo) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: calendar.backgroundColor))
                .frame(width: 10, height: 10)
            Text(calendar.summary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Toggle(calendar.summary, isOn: Binding(
                get: { manager.isCalendarEnabled(calendar.id) },
                set: { _ in manager.toggleCalendar(calendar.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
        }
        .frame(minHeight: 34)
        .padding(.horizontal, 12)
    }

    /// Enabled calendars first, otherwise in the order Google returns them.
    private func sortCalendars() {
        let calendars = manager.calendars
        let enabled = calendars.filter { manager.isCalendarEnabled($0.id) }
        let disabled = calendars.filter { !manager.isCalendarEnabled($0.id) }
        calendarOrder = (enabled + disabled).map(\.id)
    }

    /// The calendars in `calendarOrder`, with any not yet placed at the end.
    private var orderedCalendars: [CalendarInfo] {
        let position = Dictionary(uniqueKeysWithValues: calendarOrder.enumerated().map { ($1, $0) })
        return manager.calendars.enumerated()
            .sorted { lhs, rhs in
                let l = position[lhs.element.id] ?? calendarOrder.count + lhs.offset
                let r = position[rhs.element.id] ?? calendarOrder.count + rhs.offset
                return l < r
            }
            .map(\.element)
    }

    // MARK: - General tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                switchRow("Open at login", isOn: launchAtLoginBinding)
                rowSeparator
                settingRow("Updates") {
                    Button("Check now") {
                        updateManager.checkForUpdates()
                    }
                    .controlSize(.small)
                    .disabled(!updateManager.canCheckForUpdates)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Account")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                card {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Google Calendar")
                            Text("Connected")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button("Disconnect") {
                            Task { await manager.signOut() }
                        }
                        .controlSize(.small)
                    }
                    .frame(minHeight: 48)
                    .padding(.horizontal, 12)
                }
            }

            Spacer(minLength: 0)

            trademarkLine
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Signed out

    private var signedOutContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Text("Connect your calendar")
                    .font(.system(size: 15, weight: .semibold))
                Text("Countdown reads your Google Calendar and shows a circle counting down to your next event.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if manager.config == nil {
                    setupNotice
                } else {
                    Button {
                        Task { await manager.signIn() }
                    } label: {
                        Image("GoogleSignIn")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 36)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 24)

            trademarkLine
        }
    }

    // MARK: - Footer

    private var trademarkLine: some View {
        Text("Google Calendar is a trademark of Google LLC")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text(versionString)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 6) {
                        Text("Quit")
                            .foregroundStyle(.secondary)
                        Text("⌘Q")
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
            .font(.system(size: 11))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "v\(v)"
    }

    // MARK: - Card + row helpers

    /// A grouped, rounded card holding rows separated by inset dividers.
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    /// A label on the left with its control on the right.
    private func settingRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(label)
            Spacer(minLength: 0)
            control()
        }
        .frame(minHeight: 36)
        .padding(.horizontal, 12)
    }

    private func switchRow(_ label: String, isOn: Binding<Bool>) -> some View {
        settingRow(label) {
            Toggle(label, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    /// A secondary note under the row above it.
    private func rowCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.top, -4)
            .padding(.bottom, 10)
    }

    private var rowSeparator: some View {
        Divider()
            .padding(.leading, 12)
    }

    // MARK: - Bindings

    private var meetingsOnlyBinding: Binding<Bool> {
        Binding(
            get: { manager.model.meetingsOnly },
            set: { manager.setMeetingsOnly($0) }
        )
    }

    private var hideDeclinedBinding: Binding<Bool> {
        Binding(
            get: { manager.model.hideDeclinedEvents },
            set: { manager.setHideDeclinedEvents($0) }
        )
    }

    private var hideTasksAndBirthdaysBinding: Binding<Bool> {
        Binding(
            get: { manager.model.hideTasksAndBirthdays },
            set: { manager.setHideTasksAndBirthdays($0) }
        )
    }

    private var hideFocusTimeBinding: Binding<Bool> {
        Binding(
            get: { manager.model.hideFocusTime },
            set: { manager.setHideFocusTime($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Registration can fail if user denied in System Settings
                }
            }
        )
    }

    private var showEventDetailsBinding: Binding<Bool> {
        Binding(
            get: { manager.model.showingEventDetails },
            set: { manager.model.showingEventDetails = $0 }
        )
    }

    private var showMeetingProgressBinding: Binding<Bool> {
        Binding(
            get: { manager.model.showMeetingProgress },
            set: { manager.setShowMeetingProgress($0) }
        )
    }

    private var sizeModeBinding: Binding<SizeMode> {
        Binding(
            get: { manager.model.sizeMode },
            set: { manager.model.sizeMode = $0 }
        )
    }

    private var autoRepositionBinding: Binding<Bool> {
        Binding(
            get: { manager.model.autoReposition },
            set: { manager.model.autoReposition = $0 }
        )
    }

    private var repositionCornerBinding: Binding<ScreenCorner> {
        Binding(
            get: { manager.model.repositionCorner },
            set: { manager.model.repositionCorner = $0 }
        )
    }
}

private extension SettingsTab {
    var title: String {
        switch self {
        case .circle: "Circle"
        case .events: "Events"
        case .calendars: "Calendars"
        case .general: "General"
        }
    }

    var symbolName: String {
        switch self {
        case .circle: "clock"
        case .events: "line.3.horizontal.decrease"
        case .calendars: "calendar"
        case .general: "gearshape"
        }
    }
}

/// A small drawing of a screen whose four corners are buttons, for choosing
/// where the circle moves to when displays change.
private struct ScreenCornerPicker: View {
    @Binding var selection: ScreenCorner

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.secondary, lineWidth: 1.5)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    cornerButton(.topLeft, label: "Top left")
                    Spacer(minLength: 0)
                    cornerButton(.topRight, label: "Top right")
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    cornerButton(.bottomLeft, label: "Bottom left")
                    Spacer(minLength: 0)
                    cornerButton(.bottomRight, label: "Bottom right")
                }
            }
            .padding(3.5)
        }
        .frame(width: 48, height: 31)
    }

    private func cornerButton(_ corner: ScreenCorner, label: String) -> some View {
        Button {
            selection = corner
        } label: {
            RoundedRectangle(cornerRadius: 2)
                .fill(selection == corner ? Color.accentColor : Color.secondary.opacity(0.45))
                .frame(width: 12, height: 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selection == corner ? .isSelected : [])
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
