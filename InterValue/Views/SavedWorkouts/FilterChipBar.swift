import SwiftUI

struct FilterChipBar: View {
    let categories: [String]
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    chipButton(for: category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func chipButton(for category: String) -> some View {
        let isSelected = selected == category
        let icon = WorkoutCategories.icon(for: category)
        Button {
            selected = category
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                }
                Text(category)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

#Preview {
    @Previewable @State var selected = "All"
    FilterChipBar(categories: WorkoutCategories.defaults, selected: $selected)
        .padding(.vertical)
}
