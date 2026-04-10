// ABOUTME: Menu bar popover showing event status, Google account controls, and event filter.
// ABOUTME: Provides connect/disconnect for Google Calendar, a meetings-only toggle, and calendar selection.

import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var manager: CalendarManager
    let updateManager: UpdateManager
    var maxContentHeight: CGFloat? = 720

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            if manager.config == nil {
                setupNotice
                    .padding(.bottom, 16)
            }

            if manager.isSignedIn {
                displaySection
                sectionDivider
                eventsSection
                if !manager.calendars.isEmpty {
                    sectionDivider
                    calendarsSection
                }
                sectionDivider
            }

            accountSection

            if let error = manager.errorMessage {
                errorBanner(error)
                    .padding(.top, 14)
            }

            sectionDivider

            generalSection

            footer
                .padding(.top, 14)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .frame(width: 300, alignment: .leading)

        if let maxContentHeight {
            ScrollView { content }
                .frame(width: 300)
                .frame(maxHeight: maxContentHeight)
        } else {
            content
        }
    }

    // MARK: - Setup notice

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
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Sections

    @ViewBuilder
    private var displaySection: some View {
        section("Display") {
            labeledControl("Circle size", trailingLabelAccessory: AnyView(AutoModeHelpButton())) {
                Picker("", selection: sizeModeBinding) {
                    Text("Standard").tag(SizeMode.standard)
                    Text("Compact").tag(SizeMode.compact)
                    Text("Auto").tag(SizeMode.auto)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            labeledControl("Event details") {
                Picker("", selection: showEventDetailsBinding) {
                    Text("Show").tag(true)
                    Text("Hide").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 10) {
                inlineToggle("Auto-reposition on display change", isOn: autoRepositionBinding)

                if manager.model.autoReposition {
                    Picker("", selection: repositionCornerBinding) {
                        Image(systemName: "arrow.up.left").tag(ScreenCorner.topLeft)
                        Image(systemName: "arrow.up.right").tag(ScreenCorner.topRight)
                        Image(systemName: "arrow.down.left").tag(ScreenCorner.bottomLeft)
                        Image(systemName: "arrow.down.right").tag(ScreenCorner.bottomRight)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.leading, 26)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.default, value: manager.model.autoReposition)
    }

    @ViewBuilder
    private var eventsSection: some View {
        section("Events") {
            labeledControl("Show countdown for") {
                Picker("", selection: meetingsOnlyBinding) {
                    Text("All events").tag(false)
                    Text("Meetings only").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            inlineToggle("Hide declined & cancelled", isOn: hideDeclinedBinding)
            inlineToggle("Hide tasks & birthdays", isOn: hideTasksAndBirthdaysBinding)
        }
    }

    @ViewBuilder
    private var calendarsSection: some View {
        section("Calendars") {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(Array(manager.calendars.enumerated()), id: \.element.id) { index, calendar in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: calendar.backgroundColor))
                                .frame(width: 10, height: 10)
                            Text(calendar.summary)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 8)
                            Toggle("", isOn: Binding(
                                get: { manager.isCalendarEnabled(calendar.id) },
                                set: { _ in manager.toggleCalendar(calendar.id) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)

                        if index < manager.calendars.count - 1 {
                            Divider().padding(.leading, 30)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.visible)
            .defaultScrollAnchor(.top)
            .frame(height: calendarsListMaxHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(alignment: .bottom) {
                if manager.calendars.count > visibleCalendarCap {
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 18)
                    .allowsHitTesting(false)
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(bottomLeading: 8, bottomTrailing: 8),
                            style: .continuous
                        )
                    )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var visibleCalendarCap: Int { 6 }

    /// Caps the calendars list at roughly six visible rows; beyond that the
    /// list scrolls in place so the surrounding sections stay in view.
    private var calendarsListMaxHeight: CGFloat {
        let approxRowHeight: CGFloat = 30
        return approxRowHeight * CGFloat(visibleCalendarCap)
    }

    @ViewBuilder
    private var accountSection: some View {
        section("Account") {
            if manager.isSignedIn {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Google Calendar")
                            .font(.system(size: 12, weight: .medium))
                        Text("Connected")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Disconnect") {
                        Task { await manager.signOut() }
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            } else if manager.config != nil {
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
    }

    @ViewBuilder
    private var generalSection: some View {
        section("General") {
            inlineToggle("Launch at login", isOn: launchAtLoginBinding)

            Button {
                updateManager.checkForUpdates()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11))
                    Text("Check for updates…")
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!updateManager.canCheckForUpdates)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 6) {
            Divider()
                .padding(.bottom, 2)

            HStack {
                Text(versionString)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit Countdown") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Text("Google Calendar is a trademark of Google LLC")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
    }

    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "Countdown v\(v)"
    }

    // MARK: - Section + control helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(.vertical, 14)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private enum LabelStyle { case primary, secondary }

    @ViewBuilder
    private func labeledControl<Content: View>(
        _ label: String,
        labelStyle: LabelStyle = .primary,
        trailingLabelAccessory: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(labelStyle == .primary ? .secondary : .tertiary)
                if let trailingLabelAccessory { trailingLabelAccessory }
            }
            content()
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func inlineToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 12))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
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

private struct AutoModeHelpButton: View {
    @State private var showingHelp = false

    var body: some View {
        Button {
            showingHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
            Text("Auto uses the compact size when only your built-in display is active, and the standard size when an external display is connected.")
                .font(.caption)
                .frame(width: 220)
                .padding(10)
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
