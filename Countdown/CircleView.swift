// ABOUTME: Animated countdown circle showing minutes until the next calendar event.
// ABOUTME: Transitions from green to red and pulses when the event is imminent.

import SwiftUI

struct CircleView: View {
    let minutesRemaining: Int
    let colourProgress: Double  // 0 = green, 1 = red
    let isFlashing: Bool
    let isIdle: Bool
    let ringProgress: Double  // 0 = no ring, 1 = full ring

    @State private var flashOpacity: Double = 0.85

    private var circleColour: Color {
        if isIdle {
            return Color(white: 0.5)
        }
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
                .opacity(flashOpacity)
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.3), radius: 10)

            if ringProgress > 0 {
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Color.white.opacity(0.6), lineWidth: 3)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 86, height: 86)
            }

            if !isIdle {
                Text("\(minutesRemaining)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 90, height: 90)
        .onChange(of: isFlashing) { _, flashing in
            if flashing {
                startFlashing()
            } else {
                stopFlashing()
            }
        }
        .onAppear {
            if isFlashing {
                startFlashing()
            }
        }
    }

    private func startFlashing() {
        flashOpacity = 1.0
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            flashOpacity = 0.4
        }
    }

    private func stopFlashing() {
        withAnimation(.default) {
            flashOpacity = 0.85
        }
    }
}
