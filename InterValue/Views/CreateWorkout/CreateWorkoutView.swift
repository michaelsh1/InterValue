import SwiftUI
import SwiftData

struct CreateWorkoutView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Environment(\.colorScheme) private var colorScheme
    @State private var vm: CreateWorkoutViewModel
    @State private var expandedSets: Set<UUID> = []
    @State private var showPerSetSettings: Bool = false
    @State private var showAIDrawer: Bool = false
    @State private var aiUnavailableMessage: String? = nil
    @State private var showIconPicker: Bool = false
    @State private var draggingIndex: Int? = nil
    @State private var dragOffsetY: CGFloat = 0
    @State private var openSwipeID: UUID? = nil
    @State private var deleteCount = 0
    private let rowSlotHeight: CGFloat = 46

    init(workout: Workout? = nil, settings: AppSettings? = nil) {
        _vm = State(initialValue: CreateWorkoutViewModel(workout: workout, settings: settings))
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                categorySection
                timerSection
                perSetSettingsSection
                bellSoundSection
            }
            .scrollDismissesKeyboard(.immediately)
            .onScrollPhaseChange { _, phase in
                if phase.isScrolling { openSwipeID = nil }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationTitle(vm.isEditMode ? "Edit Workout" : "Create Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .fontWeight(.semibold)
                        .disabled(!vm.isValid)
                }
            }
            .alert("Custom Category", isPresented: $vm.showCustomCategoryAlert) {
                TextField("Category name", text: $vm.customCategoryInput)
                Button("Add") {
                    let trimmed = vm.customCategoryInput.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { vm.categories.insert(trimmed) }
                    vm.customCategoryInput = ""
                }
                Button("Cancel", role: .cancel) {
                    vm.customCategoryInput = ""
                }
            } message: {
                Text("Enter a name for your custom category.")
            }
            .alert(
                "Cannot Save",
                isPresented: Binding(
                    get: { vm.validationError != nil },
                    set: { if !$0 { vm.validationError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.validationError ?? "")
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.resizes)
        .sheet(isPresented: $showIconPicker) {
            WorkoutIconPickerSheet(selectedIcon: $vm.iconName)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Generate Workout",
            isPresented: Binding(get: { aiUnavailableMessage != nil }, set: { if !$0 { aiUnavailableMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(aiUnavailableMessage ?? "")
        }
        .sheet(isPresented: $showAIDrawer) {
            AIGenerateDrawerView(
                setCount: vm.sets,
                existingConfigs: vm.perSetConfigs,
                onApply: { generated in
                    // "From Text" decides its own set count; "Build" already returns vm.sets sets
                    vm.sets = generated.sets.count
                    vm.applyGeneratedConfigs(generated.sets)
                    if vm.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        vm.name = String(generated.name.prefix(40))
                    }
                    let validCategories = Set(WorkoutCategories.defaults.filter { $0 != "All" && $0 != "Custom" })
                    for cat in generated.categories where validCategories.contains(cat) {
                        vm.categories.insert(cat)
                    }
                    showPerSetSettings = true
                }
            )
            .presentationDetents([.fraction(0.7), .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    showIconPicker = true
                } label: {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 36, height: 36)
                        .overlay {
                            if let icon = vm.iconName {
                                Image(icon)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                                    .foregroundStyle(.primary)
                            } else {
                                Image(systemName: "circle.dashed")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .overlay { Circle().strokeBorder(Color(.separator), lineWidth: 0.5) }
                }
                .buttonStyle(.plain)

                TextField("Workout Name", text: $vm.name)
                    .onChange(of: vm.name) { _, new in
                        if new.count > 40 { vm.name = String(new.prefix(40)) }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        Section("Category") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectableCategories, id: \.self) { cat in
                        CategoryChip(
                            title: cat,
                            icon: WorkoutCategories.icon(for: cat),
                            isSelected: vm.categories.contains(cat),
                            action: { vm.toggleCategory(cat) }
                        )
                    }
                    CategoryChip(
                        title: "+ Custom",
                        icon: nil,
                        isSelected: false,
                        action: { vm.showCustomCategoryAlert = true }
                    )
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        Section("Timer") {
            SetsSlider(title: "SETS", sets: $vm.sets)
            DualTimePicker(title: "WORK",    totalSeconds: $vm.workSeconds)
            DualTimePicker(title: "REST",    totalSeconds: $vm.restSeconds)
            DualTimePicker(title: "PREPARE", totalSeconds: $vm.prepareSeconds)
        }
    }

    private var selectableCategories: [String] {
        WorkoutCategories.defaults.filter { $0 != "All" && $0 != "Custom" }
    }

    // MARK: - Per-Set Settings

    private func dragTargetIndex(source: Int, offsetY: CGFloat) -> Int {
        let steps = Int((offsetY / rowSlotHeight).rounded())
        return max(0, min(vm.sets - 1, source + steps))
    }

    private func rowShiftOffset(for i: Int) -> CGFloat {
        guard let source = draggingIndex else { return 0 }
        let target = dragTargetIndex(source: source, offsetY: dragOffsetY)
        if i == source { return 0 }
        if source < target && i > source && i <= target { return -rowSlotHeight }
        if source > target && i < source && i >= target { return rowSlotHeight }
        return 0
    }

    private var perSetSettingsSection: some View {
        Section {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showPerSetSettings.toggle()
                }
            } label: {
                HStack {
                    Text("Per-Set Settings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showPerSetSettings ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPerSetSettings)
                }
            }
            .listRowInsets(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))

            if showPerSetSettings && AIService.unavailableReason != "" {
                Button {
                    if let reason = AIService.unavailableReason {
                        aiUnavailableMessage = reason
                    } else {
                        showAIDrawer = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colorScheme == .dark ? .white : Color.blue)
                        Text("Generate Workout")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colorScheme == .dark ? .white : Color.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue.opacity(0.1))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.blue.opacity(0.7), lineWidth: 1.5)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)

                VStack(spacing: 8) {
                    ForEach(Array(vm.perSetConfigs.enumerated()), id: \.element.id) { i, item in
                        let isDragging = draggingIndex == i
                        SetSettingsRow(
                            setIndex: i,
                            config: configBinding(for: i),
                            isExpanded: expandedSets.contains(item.id),
                            globalWorkSeconds: vm.workSeconds,
                            globalRestSeconds: vm.restSeconds,
                            onToggleExpand: {
                                openSwipeID = nil
                                if expandedSets.contains(item.id) { expandedSets.remove(item.id) }
                                else { expandedSets.insert(item.id) }
                            },
                            onDragHandleChanged: { value in
                                if draggingIndex == nil {
                                    draggingIndex = i
                                    openSwipeID = nil
                                    expandedSets.removeAll()
                                }
                                dragOffsetY = value.translation.height
                            },
                            onDragHandleEnded: { value in
                                guard let source = draggingIndex else { return }
                                let target = dragTargetIndex(source: source, offsetY: value.translation.height)
                                if target != source {
                                    vm.perSetConfigs.move(
                                        fromOffsets: IndexSet(integer: source),
                                        toOffset: target > source ? target + 1 : target
                                    )
                                }
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    draggingIndex = nil
                                    dragOffsetY = 0
                                }
                            },
                            canDelete: vm.sets > 1,
                            isSwipeOpen: openSwipeID == item.id,
                            onSwipeOpenChange: { open in
                                if open { openSwipeID = item.id }
                                else if openSwipeID == item.id { openSwipeID = nil }
                            },
                            onDelete: {
                                expandedSets.remove(item.id)
                                openSwipeID = nil
                                deleteCount += 1
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    vm.deleteSet(id: item.id)
                                }
                            }
                        )
                        .offset(y: isDragging ? dragOffsetY : rowShiftOffset(for: i))
                        .zIndex(isDragging ? 1 : 0)
                        .shadow(color: isDragging ? .black.opacity(0.18) : .clear, radius: 8, y: 4)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: rowShiftOffset(for: i))
                    }
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: deleteCount)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    private func configBinding(for index: Int) -> Binding<PerSetConfig> {
        Binding(
            get: { vm.perSetConfigs.indices.contains(index) ? vm.perSetConfigs[index] : PerSetConfig() },
            set: { if vm.perSetConfigs.indices.contains(index) { vm.perSetConfigs[index] = $0 } }
        )
    }

    // MARK: - Sound

    private var bellSoundBinding: Binding<String> {
        Binding(
            get: { vm.bellSoundOverride ?? "" },
            set: { newValue in
                vm.bellSoundOverride = newValue.isEmpty ? nil : newValue
                let name = newValue.isEmpty ? vm.defaultBellSoundName : newValue
                let preview = SoundManager.variant("twice", of: name)
                SoundManager.shared.previewSound(soundName: preview)
            }
        )
    }

    private var countdownBinding: Binding<Bool> {
        Binding(
            get: { vm.countdownOverride ?? vm.defaultCountdownEnabled },
            set: { vm.countdownOverride = $0 }
        )
    }

    private var bellSoundSection: some View {
        Section("Sound") {
            Picker("Bell Sound", selection: bellSoundBinding) {
                Text("Default").tag("")
                ForEach(SettingsViewModel.soundOptions, id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            Toggle("Countdown", isOn: countdownBinding)
        }
    }

    // MARK: - Helpers

    private func saveAndDismiss() {
        if vm.name.trimmingCharacters(in: .whitespaces).isEmpty {
            vm.validationError = "Please enter a workout name."
            return
        }
        if vm.workSeconds == 0 {
            vm.validationError = "Work time must be greater than 0."
            return
        }
        vm.save(context: modelContext)
        dismiss()
    }
}

// MARK: - WorkoutIconPickerSheet

struct WorkoutIconPickerSheet: View {
    @Binding var selectedIcon: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            Text("Workout Icon")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    // None tile
                    Button {
                        selectedIcon = nil
                        dismiss()
                    } label: {
                        let isSelected = selectedIcon == nil
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                            .frame(height: 56)
                            .overlay {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(isSelected ? Color.white : Color(.tertiaryLabel))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)

                    ForEach(WorkoutIcons.available, id: \.self) { icon in
                        let isSelected = selectedIcon == icon
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                                .frame(height: 56)
                                .overlay {
                                    Image(icon)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(12)
                                        .foregroundStyle(isSelected ? .white : .primary)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
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

// MARK: - SetSettingsRow

private struct SetSettingsRow: View {
    let setIndex: Int
    @Binding var config: PerSetConfig
    let isExpanded: Bool
    let globalWorkSeconds: Int
    let globalRestSeconds: Int
    let onToggleExpand: () -> Void
    var onDragHandleChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragHandleEnded: ((DragGesture.Value) -> Void)? = nil
    var canDelete: Bool = false
    var isSwipeOpen: Bool = false
    var onSwipeOpenChange: ((Bool) -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var swipeX: CGFloat = 0
    @State private var swipeStartX: CGFloat = 0
    @State private var isSwiping = false
    @State private var rowWidth: CGFloat = 0
    private let revealWidth: CGFloat = 64
    private let tileGap: CGFloat = 6
    private let snap = Animation.spring(response: 0.3, dampingFraction: 0.86)

    private var isNamed: Bool {
        !config.label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isPastDeleteThreshold: Bool {
        rowWidth > 0 && -swipeX > rowWidth * 0.55
    }

    var body: some View {
        content
            .offset(x: swipeX)
            .overlay {
                if isSwipeOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .offset(x: swipeX)
                        .onTapGesture { onSwipeOpenChange?(false) }
                }
            }
            .background(alignment: .trailing) {
                if swipeX < 0 {
                    Button(action: slideOutAndDelete) {
                        // Full-height tile that stretches with the swipe; past the threshold
                        // the X jumps to ride the row's edge, like Mail's full swipe
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red)
                            .overlay(alignment: isPastDeleteThreshold ? .leading : .center) {
                                Image(systemName: "xmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: revealWidth - tileGap)
                                    .scaleEffect(min(1, -swipeX / revealWidth))
                            }
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPastDeleteThreshold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete set \(setIndex + 1)")
                    .frame(width: max(0, -swipeX - tileGap))
                    .frame(maxHeight: .infinity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .gesture(HorizontalPanGesture(
            onBegan: {
                guard canDelete else { return }
                isSwiping = true
                swipeStartX = swipeX
                onSwipeOpenChange?(true)
            },
            onChanged: { dx in
                guard isSwiping else { return }
                let x = swipeStartX + dx
                swipeX = x > 0 ? x / 5 : max(x, -rowWidth)  // rubber-band past closed
            },
            onEnded: { velocity in
                guard isSwiping else { return }
                isSwiping = false
                if isPastDeleteThreshold {
                    slideOutAndDelete()
                } else if swipeX + velocity * 0.15 < -revealWidth / 2 {
                    withAnimation(snap) { swipeX = -revealWidth }
                } else {
                    withAnimation(snap) { swipeX = 0 }
                    onSwipeOpenChange?(false)
                }
            }
        ))
        .onChange(of: isSwipeOpen) { _, open in
            if !open && !isSwiping { withAnimation(snap) { swipeX = 0 } }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPastDeleteThreshold)
        .sensoryFeedback(.selection, trigger: isSwipeOpen) { _, open in open }
    }

    private func slideOutAndDelete() {
        withAnimation(.easeOut(duration: 0.2)) {
            swipeX = -rowWidth
        } completion: {
            onDelete?()
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .font(.footnote)
                        .foregroundStyle(isNamed ? Color.secondary : Color.secondary.opacity(0.3))
                        .frame(width: 20)
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .onChanged { value in
                                    guard isNamed else { return }
                                    onDragHandleChanged?(value)
                                }
                                .onEnded { value in
                                    guard isNamed else { return }
                                    onDragHandleEnded?(value)
                                }
                        )
                    TextField("Set \(setIndex + 1) label", text: $config.label)
                        .font(.subheadline)
                        .onChange(of: config.label) { _, new in
                            if new.count > 32 { config.label = String(new.prefix(32)) }
                        }
                    Spacer()
                    Button(action: onToggleExpand) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isExpanded)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)

                if isExpanded {
                    Divider().padding(.horizontal, 12)
                    VStack(spacing: 12) {
                        HStack(alignment: .top) {
                            DualTimePicker(title: "WORK", totalSeconds: workBinding)
                            if config.workSecondsOverride != nil {
                                Button { config.workSecondsOverride = nil } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                            }
                        }
                        HStack(alignment: .top) {
                            DualTimePicker(title: "REST", totalSeconds: restBinding)
                            if config.restSecondsOverride != nil {
                                Button { config.restSecondsOverride = nil } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var workBinding: Binding<Int> {
        Binding(
            get: { config.workSecondsOverride ?? globalWorkSeconds },
            set: { config.workSecondsOverride = $0 }
        )
    }

    private var restBinding: Binding<Int> {
        Binding(
            get: { config.restSecondsOverride ?? globalRestSeconds },
            set: { config.restSecondsOverride = $0 }
        )
    }
}

// MARK: - Horizontal Pan

/// UIKit pan that only begins on mostly-horizontal drags, so vertical scrolling stays with the Form.
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    var onBegan: () -> Void
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        switch pan.state {
        case .began:
            onBegan()
            onChanged(pan.translation(in: pan.view).x)
        case .changed:
            onChanged(pan.translation(in: pan.view).x)
        case .ended, .cancelled, .failed:
            onEnded(pan.velocity(in: pan.view).x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

// MARK: - Preview

#Preview("Create") {
    CreateWorkoutView()
        .modelContainer(for: [Workout.self, WorkoutInterval.self, AppSettings.self], inMemory: true)
}

#Preview("Edit") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, WorkoutInterval.self, AppSettings.self, configurations: config)
    let workout = Workout(
        name: "Abs Blast", category: "Abs",
        sets: 5, workSeconds: 30, restSeconds: 10, prepareSeconds: 5
    )
    container.mainContext.insert(workout)
    return CreateWorkoutView(workout: workout)
        .modelContainer(container)
}
