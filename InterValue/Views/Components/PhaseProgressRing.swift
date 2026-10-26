import SwiftUI

/// A circular progress ring with a gray track and an animated filled arc.
/// - Parameters:
///   - progress: A value from 0.0 (empty) to 1.0 (full).
///   - color: The fill color of the progress arc.
///   - lineWidth: The stroke width of both the track and the arc.
struct PhaseProgressRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        PhaseProgressRing(progress: 0.65, color: .red)
            .frame(width: 200, height: 200)

        PhaseProgressRing(progress: 0.3, color: .blue, lineWidth: 8)
            .frame(width: 120, height: 120)
    }
    .padding()
}
