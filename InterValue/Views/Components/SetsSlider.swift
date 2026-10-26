import SwiftUI

/// A labeled slider for selecting a set count in the range 1–50.
struct SetsSlider: View {
    let title: String
    @Binding var sets: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text("\(sets)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: sets)
                    .frame(minWidth: 32, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { Double(sets) },
                        set: { sets = Int($0.rounded()) }
                    ),
                    in: 1...50,
                    step: 1
                )
            }
        }
    }
}

#Preview {
    @Previewable @State var sets = 8
    SetsSlider(title: "SETS", sets: $sets)
        .padding()
}
