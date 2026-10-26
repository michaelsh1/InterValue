import SwiftUI

/// A horizontal carousel-style picker for selecting a duration in minutes and seconds.
/// Binds to a total-seconds `Int` and converts internally.
struct DualTimePicker: View {
    let title: String
    @Binding var totalSeconds: Int

    private var minutes: Int { totalSeconds / 60 }
    private var seconds: Int { totalSeconds % 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                HorizontalNumberPicker(
                    range: 0...59,
                    selectedValue: minutesBinding,
                    suffix: "min"
                )

                HorizontalNumberPicker(
                    range: 0...59,
                    selectedValue: secondsBinding,
                    suffix: "sec"
                )
            }
        }
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { minutes },
            set: { totalSeconds = $0 * 60 + seconds }
        )
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: { seconds },
            set: { totalSeconds = minutes * 60 + $0 }
        )
    }
}

#Preview {
    @Previewable @State var total = 90
    DualTimePicker(title: "WORK", totalSeconds: $total)
        .padding()
}
