// ABOUTME: Horizontal bar showing how much of the meeting in progress is left.
// ABOUTME: Drains from full to empty, with the minutes remaining beside it.

import SwiftUI

struct MeetingProgressBar: View {
    let progress: Double  // 1 = just started, 0 = ending now
    let minutesRemaining: Int
    var compact: Bool = false

    /// Fixed rather than fitted to the row above, so the fill fraction stays
    /// comparable minute to minute whatever the event title happens to be.
    private var barWidth: CGFloat { compact ? 72 : 110 }
    private var barHeight: CGFloat { compact ? 4 : 6 }
    private var fontSize: CGFloat { compact ? 11 : 13 }
    private var shadowRadius: CGFloat { compact ? 2 : 4 }

    /// Reserved for the minutes label. Standard mode balances it with an equal
    /// gap on the left so the bar sits centred under the dot rather than the
    /// bar and label together being centred, which reads as a misalignment.
    private var labelWidth: CGFloat { 24 }

    var body: some View {
        HStack(spacing: 6) {
            if !compact {
                Color.clear.frame(width: labelWidth, height: 1)
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: barWidth, height: barHeight)

                Capsule()
                    .fill(.white.opacity(0.6))
                    .frame(width: barWidth * min(1.0, max(0.0, progress)), height: barHeight)
            }

            Text("\(minutesRemaining)")
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .frame(minWidth: labelWidth, alignment: .leading)
        }
        .shadow(color: .black.opacity(0.3), radius: shadowRadius)
    }
}
