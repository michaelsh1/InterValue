import SwiftUI

/// A color picker row that opens a compact popup with 20 curated pastel swatches.
/// Looks and behaves like a native ColorPicker row, but limits choices to pastels.
struct PastelColorPicker: View {
    let label: String
    @Binding var selection: Color

    @State private var isPresented = false

    // 20 curated pastels with character
    static let palette: [(hex: String, color: Color)] = [
        ("#FF6B6B", Color(hex: "#FF6B6B")),  // Coral Red
        ("#FF6B9D", Color(hex: "#FF6B9D")),  // Hot Pink
        ("#F78FB3", Color(hex: "#F78FB3")),  // Rose
        ("#FF9A5C", Color(hex: "#FF9A5C")),  // Vivid Peach
        ("#FFB347", Color(hex: "#FFB347")),  // Mango
        ("#FFD93D", Color(hex: "#FFD93D")),  // Sunshine
        ("#6BCB77", Color(hex: "#6BCB77")),  // Fresh Green
        ("#4ECDC4", Color(hex: "#4ECDC4")),  // Turquoise
        ("#06D6A0", Color(hex: "#06D6A0")),  // Emerald
        ("#74B9FF", Color(hex: "#74B9FF")),  // Sky Blue
        ("#5E9BF0", Color(hex: "#5E9BF0")),  // Cornflower
        ("#81ECEC", Color(hex: "#81ECEC")),  // Aqua
        ("#A29BFE", Color(hex: "#A29BFE")),  // Soft Purple
        ("#C77DFF", Color(hex: "#C77DFF")),  // Vivid Lavender
        ("#E056CF", Color(hex: "#E056CF")),  // Orchid
        ("#FDCB6E", Color(hex: "#FDCB6E")),  // Warm Honey
        ("#55EFC4", Color(hex: "#55EFC4")),  // Seafoam
        ("#FD79A8", Color(hex: "#FD79A8")),  // Bubblegum
        ("#00B894", Color(hex: "#00B894")),  // Rich Mint
        ("#E17055", Color(hex: "#E17055")),  // Terracotta
    ]

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Circle()
                .fill(selection)
                .frame(width: 28, height: 28)
                .overlay { Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1) }
                .onTapGesture { isPresented = true }
        }
        .sheet(isPresented: $isPresented) {
            PastelColorSheet(label: label, selection: $selection, isPresented: $isPresented)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Sheet content

private struct PastelColorSheet: View {
    let label: String
    @Binding var selection: Color
    @Binding var isPresented: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.headline)
                .padding(.top, 20)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(PastelColorPicker.palette, id: \.hex) { entry in
                    let isSelected = entry.hex == selection.toHex()
                    Circle()
                        .fill(entry.color)
                        .frame(height: 44)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.5))
                            }
                        }
                        .overlay {
                            Circle().strokeBorder(
                                .primary.opacity(isSelected ? 0.4 : 0.1),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                        }
                        .onTapGesture {
                            selection = entry.color
                            isPresented = false
                        }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
}

#Preview {
    @Previewable @State var color = Color(hex: "#FF8FAB")
    Form {
        Section("Colors") {
            PastelColorPicker(label: "Work", selection: $color)
            PastelColorPicker(label: "Rest", selection: $color)
        }
    }
}
