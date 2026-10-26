import SwiftUI
import SwiftData

/// Sheet presented when the app is opened via an intervalue:// import deep link.
/// Shows a preview of incoming workouts, marks duplicates, then saves them.
struct ImportWorkoutsView: View {
    let workouts: [WorkoutDTO]
    var onImportComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingWorkouts: [Workout]

    @State private var expandedIDs: Set<UUID> = []
    @State private var conflictQueue: [WorkoutDTO] = []
    @State private var showConflictSheet = false
    @State private var importStarted = false

    private var existingNames: Set<String> {
        Set(existingWorkouts.map { $0.name })
    }

    private func isDuplicate(_ dto: WorkoutDTO) -> Bool {
        existingNames.contains(dto.name)
    }

    var body: some View {
        NavigationStack {
            List {
                if workouts.contains(where: { isDuplicate($0) }) {
                    Section {
                        Label {
                            Text("Some workouts share a name with ones already on your device. You'll be prompted to rename them.")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(workouts) { dto in
                        workoutRow(dto)
                    }
                } header: {
                    Text("\(workouts.count) workout\(workouts.count == 1 ? "" : "s")")
                }
            }
            .navigationTitle("Import Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { startImport() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showConflictSheet) {
                ImportConflictSheet(
                    queue: $conflictQueue,
                    modelContext: modelContext,
                    onAllResolved: {
                        showConflictSheet = false
                    }
                )
                .interactiveDismissDisabled(true)
            }
            .onChange(of: showConflictSheet) { _, isShowing in
                if !isShowing && importStarted {
                    dismiss()
                    onImportComplete()
                }
            }
        }
    }

    // MARK: - Workout Row

    @ViewBuilder
    private func workoutRow(_ dto: WorkoutDTO) -> some View {
        let duplicate = isDuplicate(dto)
        let expanded = expandedIDs.contains(dto.id)

        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expanded { expandedIDs.remove(dto.id) } else { expandedIDs.insert(dto.id) }
                }
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dto.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        if !dto.category.isEmpty {
                            Text(
                                dto.category
                                    .split(separator: ",")
                                    .map { $0.trimmingCharacters(in: .whitespaces) }
                                    .joined(separator: " · ")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Text("\(dto.sets) sets · \(dto.workSeconds)s work / \(dto.restSeconds)s rest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !dto.intervals.isEmpty {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded && !dto.intervals.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(dto.intervals) { interval in
                        HStack(spacing: 8) {
                            Text("Set \(interval.setIndex + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .leading)
                            Text(interval.label.isEmpty ? "—" : interval.label)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(duplicate ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Import Logic

    private func startImport() {
        let snapshot = existingNames
        let conflicts = workouts.filter { snapshot.contains($0.name) }
        let nonConflicts = workouts.filter { !snapshot.contains($0.name) }

        for dto in nonConflicts {
            dto.toWorkout(context: modelContext)
        }

        if conflicts.isEmpty {
            dismiss()
            onImportComplete()
        } else {
            importStarted = true
            conflictQueue = conflicts
            showConflictSheet = true
        }
    }
}

// MARK: - Import Conflict Sheet

private struct ImportConflictSheet: View {
    @Binding var queue: [WorkoutDTO]
    let modelContext: ModelContext
    let onAllResolved: () -> Void

    @State private var newName = ""
    @FocusState private var fieldFocused: Bool

    private var current: WorkoutDTO? { queue.first }

    var body: some View {
        NavigationStack {
            if let conflict = current {
                Form {
                    Section {
                        Text("A workout named **\"\(conflict.name)\"** already exists on this device.")
                            .foregroundStyle(.secondary)
                    }

                    Section("New Name") {
                        TextField("Workout name", text: $newName)
                            .focused($fieldFocused)
                            .autocorrectionDisabled()
                    }

                    Section("Incoming Workout") {
                        LabeledContent("Sets", value: "\(conflict.sets)")
                        LabeledContent("Work", value: "\(conflict.workSeconds)s")
                        LabeledContent("Rest", value: "\(conflict.restSeconds)s")
                        if !conflict.intervals.isEmpty {
                            DisclosureGroup("Per-Set Labels") {
                                ForEach(conflict.intervals) { interval in
                                    HStack {
                                        Text("Set \(interval.setIndex + 1)")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(interval.label)
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Name Conflict")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip") { advance(dto: nil) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            let name = newName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            var renamed = conflict
                            renamed.name = name
                            advance(dto: renamed)
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .onAppear {
                    newName = conflict.name + " (2)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        fieldFocused = true
                    }
                }
                .onChange(of: queue.count) { _, _ in
                    if let next = queue.first {
                        newName = next.name + " (2)"
                    }
                }
            }
        }
    }

    private func advance(dto: WorkoutDTO?) {
        if let dto { dto.toWorkout(context: modelContext) }
        queue.removeFirst()
        if queue.isEmpty { onAllResolved() }
    }
}
