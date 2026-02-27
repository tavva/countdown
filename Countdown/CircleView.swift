// ABOUTME: Animated countdown circle showing minutes until the next calendar event.
// ABOUTME: Transitions from green to red and pulses when the event is imminent.

import SwiftUI

struct CircleView: View {
    let minutesRemaining: Int
    let colourProgress: Double  // 0 = green, 1 = red
    let isFlashing: Bool
    let onDismiss: () -> Void

    @State private var flashOpacity: Double = 1.0

    private var circleColour: Color {
        if colourProgress > 55.0 / 60.0 {
            return .red
        }
        // Interpolate green -> orange -> red
        return Color(
            red: min(1.0, colourProgress * 2),
            green: max(0.0, 1.0 - colourProgress * 1.5),
            blue: 0
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(circleColour)
                .opacity(isFlashing ? flashOpacity : 0.85)
                .frame(width: 80, height: 80)

            Text("\(minutesRemaining)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .onTapGesture {
            onDismiss()
        }
        .onChange(of: isFlashing) { _, flashing in
            if flashing {
                startFlashing()
            } else {
                flashOpacity = 1.0
            }
        }
        .onAppear {
            if isFlashing {
                startFlashing()
            }
        }
    }

    private func startFlashing() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            flashOpacity = 0.4
        }
    }
}
