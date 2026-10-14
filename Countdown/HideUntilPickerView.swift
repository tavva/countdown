// ABOUTME: Small window content for choosing when the hidden overlay should come back.
// ABOUTME: A date-and-time picker that refuses past times, with Hide and Cancel buttons.

import SwiftUI

struct HideUntilPickerView: View {
    @State private var date: Date
    private let earliest: Date
    let onHide: (Date) -> Void
    let onCancel: () -> Void

    init(initialDate: Date, now: Date = Date(), onHide: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        _date = State(initialValue: initialDate)
        self.earliest = now
        self.onHide = onHide
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hide Countdown until")
                .font(.system(size: 12, weight: .medium))

            DatePicker("", selection: $date, in: earliest..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            HStack(spacing: 8) {
                Text("Time")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $date, in: earliest..., displayedComponents: .hourAndMinute)
                    .datePickerStyle(.stepperField)
                    .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Hide") { onHide(date) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 200, alignment: .leading)
        .padding(16)
        .fixedSize()
    }
}
