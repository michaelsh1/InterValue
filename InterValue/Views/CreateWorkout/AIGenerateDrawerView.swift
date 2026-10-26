import SwiftUI

struct AIGenerateDrawerView: View {
    let setCount: Int
    let existingConfigs: [PerSetConfig]
    let onApply: (GeneratedWorkout) -> Void

    @Environment(\.dismiss) private var dismiss

    // Equipment
    private let fixedEquipment: [ChipOption] = [
        ChipOption("Pull-up Bar",       icon: .asset("pull-up-bar")),
        ChipOption("Dips",              icon: .asset("dips")),
        ChipOption("Jump Rope",         icon: .asset("skipping-rope")),
        ChipOption("Resistance Bands",  icon: .asset("expander")),
        ChipOption("Bodyweight",        icon: .asset("body-weight")),
        ChipOption("Rings",             icon: .asset("gymnastic-rings")),
        ChipOption("Parallettes",       icon: .asset("push-up-bar")),
    ]
    @State private var selectedEquipment: Set<String> = []
    @State private var customEquipmentText: String = ""
    @State private var customEquipmentDraft: String = ""
    @State private var showCustomEquipmentAlert = false

    // Purpose
    private let fixedPurposes: [ChipOption] = [
        ChipOption("Stretching", icon: .asset("workout-stretching")),
        ChipOption("Warm-up",    icon: .asset("workout-warm-up")),
        ChipOption("Arms",  icon: .asset("body-part-muscle")),
        ChipOption("Push",       icon: .system("arrow.up")),
        ChipOption("Pull",       icon: .system("arrow.down")),
        ChipOption("Legs",       icon: .asset("body-part-leg")),
        ChipOption("Yoga",       icon: .asset("yoga-01")),
        ChipOption("Core",       icon: .asset("body-part-six-pack")),
        ChipOption("Cardio",     icon: .asset("workout-run")),
        ChipOption("HIIT",       icon: .asset("workout-battle-ropes")),
    ]
    @State private var selectedPurposes: Set<String> = []
    @State private var customPurposeText: String = ""
    @State private var customPurposeDraft: String = ""
    @State private var showCustomPurposeAlert = false

    // Difficulty
    @State private var difficulty: Int = 2

    // Toggles
    @State private var overrideSets: Bool = true
    @State private var generateTimes: Bool = true

    // Generation state
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil

    private var canGenerate: Bool {
        let hasEquip = !selectedEquipment.isEmpty || !customEquipmentText.isEmpty
        let hasPurp = !selectedPurposes.isEmpty || !customPurposeText.isEmpty
        return (hasEquip || hasPurp) && !isGenerating
    }

    var body: some View {
        NavigationStack {
            Form {
                equipmentSection
                purposeSection
                difficultySection
                optionsSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Generate Workout")
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isGenerating {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        Button {
                            Task { await generate() }
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .fontWeight(.semibold)
                        }
                        .disabled(!canGenerate)
                    }
                }
            }
            .alert("Custom Equipment", isPresented: $showCustomEquipmentAlert) {
                TextField("e.g. Pull-up Bar", text: $customEquipmentDraft)
                Button("Save") {
                    let trimmed = customEquipmentDraft.trimmingCharacters(in: .whitespaces)
                    customEquipmentText = trimmed
                    customEquipmentDraft = ""
                }
                Button("Remove", role: .destructive) {
                    customEquipmentText = ""
                    customEquipmentDraft = ""
                }
                Button("Cancel", role: .cancel) {
                    customEquipmentDraft = ""
                }
            } message: {
                Text("Enter a custom equipment name.")
            }
            .alert("Custom Purpose", isPresented: $showCustomPurposeAlert) {
                TextField("e.g. Mobility", text: $customPurposeDraft)
                Button("Save") {
                    let trimmed = customPurposeDraft.trimmingCharacters(in: .whitespaces)
                    customPurposeText = trimmed
                    customPurposeDraft = ""
                }
                Button("Remove", role: .destructive) {
                    customPurposeText = ""
                    customPurposeDraft = ""
                }
                Button("Cancel", role: .cancel) {
                    customPurposeDraft = ""
                }
            } message: {
                Text("Enter a custom workout purpose.")
            }
            .onChange(of: customEquipmentDraft) { _, new in
                if new.count > 100 { customEquipmentDraft = String(new.prefix(100)) }
            }
            .onChange(of: customPurposeDraft) { _, new in
                if new.count > 100 { customPurposeDraft = String(new.prefix(100)) }
            }
            .alert("Generation Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var equipmentSection: some View {
        Section("Equipment") {
            ChipFlow {
                ForEach(fixedEquipment) { option in
                    AIChip(
                        title: option.title,
                        icon: option.icon,
                        isSelected: selectedEquipment.contains(option.title)
                    ) {
                        if selectedEquipment.contains(option.title) { selectedEquipment.remove(option.title) }
                        else { selectedEquipment.insert(option.title) }
                    }
                }
                AIChip(
                    title: customEquipmentText.isEmpty ? "Custom" : customEquipmentText,
                    icon: nil,
                    isSelected: !customEquipmentText.isEmpty
                ) {
                    customEquipmentDraft = customEquipmentText
                    showCustomEquipmentAlert = true
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }

    private var purposeSection: some View {
        Section("Purpose") {
            ChipFlow {
                ForEach(fixedPurposes) { option in
                    AIChip(
                        title: option.title,
                        icon: option.icon,
                        isSelected: selectedPurposes.contains(option.title)
                    ) {
                        if selectedPurposes.contains(option.title) { selectedPurposes.remove(option.title) }
                        else { selectedPurposes.insert(option.title) }
                    }
                }
                AIChip(
                    title: customPurposeText.isEmpty ? "Custom" : customPurposeText,
                    icon: nil,
                    isSelected: !customPurposeText.isEmpty
                ) {
                    customPurposeDraft = customPurposeText
                    showCustomPurposeAlert = true
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }

    private var difficultySection: some View {
        Section("Difficulty") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(difficultyLabel)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(difficultyDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(difficulty) },
                        set: { difficulty = Int($0.rounded()) }
                    ),
                    in: 1...4, step: 1
                )
            }
            .padding(.vertical, 4)
        }
    }

    private var difficultyLabel: String {
        switch difficulty {
        case 1: return "Beginner"
        case 2: return "Intermediate"
        case 3: return "Pro"
        case 4: return "Elite"
        default: return "Intermediate"
        }
    }

    private var difficultyDescription: String {
        switch difficulty {
        case 1: return "push-ups, squats, planks"
        case 2: return "dips, pike push-ups, L-sits"
        case 3: return "muscle-ups, handstands, pistol squats"
        case 4: return "HSPU, back lever, dragon flag"
        default: return ""
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Toggle("Override Sets", isOn: $overrideSets)
            Toggle("Generate Times", isOn: $generateTimes)
        }
    }

    // MARK: - Generate

    private func generate() async {
        isGenerating = true
        defer { isGenerating = false }

        var equipment = fixedEquipment.filter { selectedEquipment.contains($0.title) }.map(\.title)
        if !customEquipmentText.isEmpty { equipment.append(customEquipmentText) }

        var purposes = fixedPurposes.filter { selectedPurposes.contains($0.title) }.map(\.title)
        if !customPurposeText.isEmpty { purposes.append(customPurposeText) }

        let existingLabels: [String]? = overrideSets ? nil : existingConfigs.map { $0.label }

        do {
            let availableCategories = WorkoutCategories.defaults.filter { $0 != "All" && $0 != "Custom" }
            let result = try await AIService.shared.generateWorkout(
                equipment: equipment,
                purposes: purposes,
                setCount: setCount,
                existingLabels: existingLabels,
                generateTimes: generateTimes,
                difficulty: difficulty,
                availableCategories: availableCategories
            )
            onApply(result)
            dismiss()
        } catch {
            errorMessage = (error as? AIServiceError)?.localizedDescription
                ?? "Generation failed. Please try again later."
        }
    }
}

// MARK: - Chip Flow Layout

private struct ChipFlow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        WrapLayout(spacing: 8) {
            content
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        layout(subviews: subviews, in: proposal.replacingUnspecifiedDimensions().width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: frame.minX + bounds.minX, y: frame.minY + bounds.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(subviews: Subviews, in maxWidth: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (frames, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - ChipOption

private enum ChipIcon {
    case asset(String)
    case system(String)
}

private struct ChipOption: Identifiable {
    let title: String
    let icon: ChipIcon?

    var id: String { title }

    init(_ title: String, icon: ChipIcon? = nil) {
        self.title = title
        self.icon = icon
    }
}

// MARK: - AIChip

private struct AIChip: View {
    let title: String
    let icon: ChipIcon?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Group {
                        switch icon {
                        case .asset(let name):
                            Image(name)
                                .resizable()
                                .scaledToFit()
                        case .system(let name):
                            Image(systemName: name)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(width: 15, height: 15)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
