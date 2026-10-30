import SwiftUI
import SwiftData

struct CreateWorkoutView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Environment(\.colorScheme) private var colorScheme
    @State private var vm: CreateWorkoutViewModel
    @State private var expandedSets: Set<UUID> = []
    @State private var showPerSetSettings: Bool = true
    @State private var showAIDrawer: Bool = false
    @State private var aiUnavailableMessage: String? = nil
    @State private var showIconPicker: Bool = false
    @State private var reorder: Reorder? = nil           // exercise or block being dragged
    @State private var rowFrames: [UUID: CGRect] = [:]   // in the per-set list's coordinate space
    @State private var cardFrames: [Int: CGRect] = [:]   // block index → card frame, same space
    @State private var expandedRoundRests: Set<Int> = [] // block indexes
    @State private var openSwipeID: UUID? = nil
    @State private var deleteCount = 0
    @State private var showClearConfirmation = false
    @State private var blockToDelete: Int? = nil       // block awaiting delete confirmation

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
                // An emptied list has no count to fill, so Build makes a sample-sized workout
                setCount: vm.sets > 0 ? vm.sets : CreateWorkoutViewModel.sampleExercises.count,
                existingConfigs: vm.perSetConfigs,
                onApply: { generated in
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
            DualTimePicker(title: "WORK",    totalSeconds: $vm.workSeconds)
            DualTimePicker(title: "REST",    totalSeconds: $vm.restSeconds)
            DualTimePicker(title: "PREPARE", totalSeconds: $vm.prepareSeconds)
        }
    }

    private var selectableCategories: [String] {
        WorkoutCategories.defaults.filter { $0 != "All" && $0 != "Custom" }
    }

    // MARK: - Per-Set Settings

    private var perSetSettingsSection: some View {
        Section {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showPerSetSettings.toggle()
                }
            } label: {
                HStack {
                    // Color.primary, not .primary: inside a Form button .primary resolves to the tint
                    Text("Per-Set Settings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(showPerSetSettings ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPerSetSettings)
                }
            }
            .listRowInsets(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))

            if showPerSetSettings {
                VStack(spacing: 10) {
                    ForEach(vm.setGroups) { group in
                        Group {
                            if let block = group.blockIndex {
                                blockCard(block, rows: group.rows)
                            } else {
                                setRows(group.rows, numberedFrom: 0)
                            }
                        }
                        .zIndex(holdsDragged(group) ? 1 : 0)  // so the dragged item floats over later groups
                    }

                    HStack(spacing: 8) {
                        listButton("+ Exercise") { vm.addSet() }
                        listButton("+ Block") { vm.addBlock() }
                        if vm.sets > 0 {
                            listButton("Clear", tint: .red) {
                                if vm.hasSetContent { showClearConfirmation = true } else { clearSets() }
                            }
                            .accessibilityLabel("Clear exercises")
                            .confirmationDialog("Clear all exercises?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                                Button("Clear All", role: .destructive) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { clearSets() }
                                }
                            } message: {
                                Text("Labels, custom times and blocks will be removed.")
                            }
                        }
                    }

                    // "" = this device can't run Apple Intelligence: no button, but the list above stays
                    if AIService.unavailableReason != "" {
                        generateWorkoutButton
                    }
                }
                .coordinateSpace(.named(reorderSpace))
                .overlay(alignment: .top) {
                    if let target = reorder?.target {
                        // Where the dragged item will land; coral when it lands inside a block
                        Capsule()
                            .fill(target.block == nil ? Color.accentColor : coral)
                            .frame(height: 3)
                            .padding(.horizontal, target.block == nil ? 0 : 10)
                            .offset(y: target.y - 1.5)
                            .allowsHitTesting(false)
                    }
                }
                .sensoryFeedback(.selection, trigger: reorder?.target)
                .sensoryFeedback(.impact(weight: .medium), trigger: deleteCount)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
    }

    private var generateWorkoutButton: some View {
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
        .buttonStyle(.plain)
    }

    /// One group's rows. Placeholders count from `numberedFrom` (a block's rows restart at "Set 1").
    private func setRows(_ rows: [(offset: Int, element: PerSetConfig)], numberedFrom first: Int) -> some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.element.id) { i, item in
                let isDragged = reorder?.item == .row(item.id)
                SetSettingsRow(
                    setIndex: i - first,
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
                        beginReorder(.row(item.id), from: rowFrames[item.id])
                        updateReorder(translation: value.translation.height)
                    },
                    onDragHandleEnded: { _ in endReorder() },
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
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(reorderSpace)) } action: { rowFrames[item.id] = $0 }
                .offset(y: isDragged ? reorder?.translation ?? 0 : 0)
                .zIndex(isDragged ? 1 : 0)
                .shadow(color: isDragged ? .black.opacity(0.25) : .clear, radius: 10, y: 4)
            }
        }
    }

    // MARK: - Reorder

    /// Starts dragging `item`, picked up from `frame` (in the list's coordinate space).
    private func beginReorder(_ item: Reorder.Item, from frame: CGRect?) {
        guard reorder == nil, let frame else { return }
        openSwipeID = nil
        reorder = Reorder(item: item, start: frame)
    }

    /// Follows the drag and picks the insertion slot nearest the dragged item's center.
    private func updateReorder(translation: CGFloat) {
        guard var r = reorder else { return }
        r.translation = translation
        let center = r.start.midY + translation
        let slots = switch r.item {
        case .row(let id): rowSlots(excluding: id, start: r.start)
        case .block(let block): blockSlots(excluding: block)
        }
        r.target = slots.min { abs($0.y - center) < abs($1.y - center) }
        reorder = r
    }

    private func endReorder() {
        guard let r = reorder else { return }
        let blockCount = vm.blocks.count
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            switch (r.item, r.target) {
            case (.row(let id), let target?): vm.moveSet(id: id, to: target.index, block: target.block)
            case (.block(let block), let target?): vm.moveBlock(block, to: target.index)
            default: break
            }
            reorder = nil
        }
        // Round-rest pickers are keyed by block index, which moving or emptying a block renumbers
        if case .block = r.item { expandedRoundRests.removeAll() }
        if vm.blocks.count != blockCount { expandedRoundRests.removeAll() }
    }

    /// Where a dragged row can land: between any two rows, and just inside or just outside each block.
    private func rowSlots(excluding id: UUID, start: CGRect) -> [DropTarget] {
        let rows = vm.perSetConfigs
        guard let from = rows.firstIndex(where: { $0.id == id }) else { return [] }
        let others = rows.filter { $0.id != id }
        var slots: [DropTarget] = []
        func add(_ index: Int, _ block: Int?, _ y: CGFloat) {
            // Neighboring groups both offer the spot between them; keep one
            if let last = slots.last, last.index == index, last.block == block { return }
            slots.append(DropTarget(index: index, block: block, y: y))
        }
        var i = 0
        while i < others.count {
            let block = others[i].blockIndex
            var end = i + 1
            while end < others.count, others[end].blockIndex == block { end += 1 }
            let card = block.flatMap { cardFrames[$0] }
            if let card { add(i, nil, card.minY - 5) }                       // above the block
            for k in i..<end {
                if let f = rowFrames[others[k].id] { add(k, block, f.minY - 4) }
            }
            if let f = rowFrames[others[end - 1].id] { add(end, block, f.maxY + 4) }
            if let card { add(end, nil, card.maxY + 5) }                     // below the block
            i = end
        }
        // It was its block's only row: dropping it back keeps the block
        if let block = rows[from].blockIndex, !others.contains(where: { $0.blockIndex == block }) {
            slots.append(DropTarget(index: from, block: block, y: start.midY))
        }
        return slots
    }

    /// Where a dragged block can land: before or after any standalone row or other block.
    private func blockSlots(excluding block: Int) -> [DropTarget] {
        let others = vm.perSetConfigs.filter { $0.blockIndex != block }
        var slots: [DropTarget] = []
        var i = 0
        while i < others.count {
            let other = others[i].blockIndex
            var end = i + 1
            if other != nil { while end < others.count, others[end].blockIndex == other { end += 1 } }
            if let f = other.flatMap({ cardFrames[$0] }) ?? rowFrames[others[i].id] {
                slots.append(DropTarget(index: i, block: nil, y: f.minY - 5))
                if end == others.count { slots.append(DropTarget(index: end, block: nil, y: f.maxY + 5)) }
            }
            i = end
        }
        return slots
    }

    private func holdsDragged(_ group: SetGroup) -> Bool {
        switch reorder?.item {
        case .row(let id): group.rows.contains { $0.element.id == id }
        case .block(let block): group.blockIndex == block
        case nil: false
        }
    }

    // MARK: - Repeat Blocks

    private func blockCard(_ block: Int, rows: [(offset: Int, element: PerSetConfig)]) -> some View {
        let binding = blockBinding(block)
        let isRestExpanded = expandedRoundRests.contains(block)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Drags the whole block
                Image(systemName: "line.3.horizontal")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .frame(width: 20, height: 30)
                    .contentShape(Rectangle().inset(by: -8))
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { value in
                                beginReorder(.block(block), from: cardFrames[block])
                                updateReorder(translation: value.translation.height)
                            }
                            .onEnded { _ in endReorder() }
                    )
                Image(systemName: "repeat")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(coral)
                Text("Block \(block + 1)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                roundsStepper(binding.rounds)
                Button {
                    if vm.blockHasContent(block) { blockToDelete = block } else { deleteBlock(block) }
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete block \(block + 1)")
                .confirmationDialog(
                    "Delete Block \(block + 1)?",
                    isPresented: Binding(get: { blockToDelete == block }, set: { if !$0 { blockToDelete = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Delete Block", role: .destructive) { deleteBlock(block) }
                } message: {
                    Text("Its exercises will be removed too.")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            blockDivider

            VStack(alignment: .leading, spacing: 8) {
                setRows(rows, numberedFrom: rows.first?.offset ?? 0)

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { vm.addSet(toBlock: block) }
                } label: {
                    Text("+ Add exercise")
                        .font(.subheadline)
                        .foregroundStyle(coral)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(8)

            blockDivider

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isRestExpanded { expandedRoundRests.remove(block) } else { expandedRoundRests.insert(block) }
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Rest between rounds")
                        .font(.subheadline)
                    Spacer()
                    Text(clock(binding.wrappedValue.restBetweenRoundsSeconds))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isRestExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isRestExpanded {
                DualTimePicker(title: "ROUND REST", totalSeconds: binding.restBetweenRoundsSeconds)
                    .padding([.horizontal, .bottom], 12)
            }
        }
        .background(coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))  // opaque while dragged
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(coral, lineWidth: 1.5)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(reorderSpace)) } action: { cardFrames[block] = $0 }
        .offset(y: reorder?.item == .block(block) ? reorder?.translation ?? 0 : 0)
        .shadow(color: reorder?.item == .block(block) ? .black.opacity(0.25) : .clear, radius: 10, y: 4)
    }

    private var blockDivider: some View {
        coral.opacity(0.35).frame(height: 0.5)
    }

    /// Compact − ×N + control; the system Stepper is too tall for the block header.
    private func roundsStepper(_ rounds: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            Button { rounds.wrappedValue -= 1 } label: {
                Image(systemName: "minus")
                    .frame(width: 34, height: 30)
                    .contentShape(Rectangle())
            }
            .disabled(rounds.wrappedValue <= 1)
            .accessibilityLabel("Fewer rounds")

            Text("×\(rounds.wrappedValue)")
                .foregroundStyle(Color.primary)
                .monospacedDigit()
                .frame(minWidth: 30)

            Button { rounds.wrappedValue += 1 } label: {
                Image(systemName: "plus")
                    .frame(width: 34, height: 30)
                    .contentShape(Rectangle())
            }
            .disabled(rounds.wrappedValue >= 20)
            .accessibilityLabel("More rounds")
        }
        .buttonStyle(.plain)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(coral)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func deleteBlock(_ block: Int) {
        // Expanded round-rest pickers are keyed by block index, which shifts down past the deleted block
        expandedRoundRests = Set(expandedRoundRests.compactMap { $0 == block ? nil : $0 > block ? $0 - 1 : $0 })
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { vm.deleteBlock(block) }
    }

    private func clearSets() {
        expandedSets.removeAll()
        expandedRoundRests.removeAll()
        openSwipeID = nil
        vm.clearSets()
    }

    private func listButton(_ title: String, tint: Color = .accentColor, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85), action)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func blockBinding(_ block: Int) -> Binding<WorkoutBlock> {
        Binding(
            get: { vm.blocks.indices.contains(block) ? vm.blocks[block] : WorkoutBlock(rounds: 1, restBetweenRoundsSeconds: 0) },
            set: { if vm.blocks.indices.contains(block) { vm.blocks[block] = $0 } }
        )
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
                        .foregroundStyle(Color.secondary)
                        .frame(width: 20, height: 22)
                        .contentShape(Rectangle().inset(by: -10))  // finger-sized grab area, same layout
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .onChanged { onDragHandleChanged?($0) }
                                .onEnded { onDragHandleEnded?($0) }
                        )
                    TextField(config.placeholder ?? "Set \(setIndex + 1) label", text: $config.label)
                        .font(.subheadline)
                        .onChange(of: config.label) { _, new in
                            if new.count > 32 { config.label = String(new.prefix(32)) }
                        }
                    Spacer()
                    // Work / rest at a glance; values that override the defaults stand out
                    HStack(spacing: 0) {
                        Text(clock(workBinding.wrappedValue))
                            .foregroundStyle(config.workSecondsOverride == nil ? Color.primary : coral)
                            .fontWeight(config.workSecondsOverride == nil ? .regular : .semibold)
                        Text(" / ")
                            .foregroundStyle(.secondary)
                        Text(clock(restBinding.wrappedValue))
                            .foregroundStyle(config.restSecondsOverride == nil ? Color.secondary : coral)
                            .fontWeight(config.restSecondsOverride == nil ? .regular : .semibold)
                    }
                    .font(.footnote.monospacedDigit())
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

private func clock(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

/// Repeat-block accent; also marks per-set times that override the defaults.
private let coral = Color(hex: "#FF6B6B")

// MARK: - Reorder Types

private let reorderSpace = "perSetList"

/// An exercise row, or a whole block, being dragged to a new spot.
private struct Reorder {
    enum Item: Equatable { case row(UUID), block(Int) }
    let item: Item
    let start: CGRect               // item frame at pickup
    var translation: CGFloat = 0
    var target: DropTarget? = nil
}

/// Where a dragged item would land: an insertion index into the rows (counted without the
/// dragged rows), the block a dropped row joins, and where to draw the insertion line.
private struct DropTarget: Equatable {
    let index: Int
    let block: Int?
    let y: CGFloat
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
