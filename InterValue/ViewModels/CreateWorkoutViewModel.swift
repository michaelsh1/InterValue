import Foundation
import Observation
import SwiftData

struct PerSetConfig: Identifiable {
    let id = UUID()
    var label: String = ""
    var placeholder: String? = nil  // sample label shown while empty (new workouts only)
    var workSecondsOverride: Int? = nil
    var restSecondsOverride: Int? = nil
    var blockIndex: Int? = nil    // index into blocks; a block's rows are always consecutive

    /// Something the user entered that removing the row would lose.
    var hasContent: Bool { !label.isEmpty || workSecondsOverride != nil || restSecondsOverride != nil }
}

/// Consecutive rows that share a repeat block, or a run of standalone rows.
struct SetGroup: Identifiable {
    let id: UUID            // first row's id
    let blockIndex: Int?
    // A snapshot, not a range: SwiftUI can render a group after rows were deleted,
    // and indexing the live array with an old range would crash
    var rows: [(offset: Int, element: PerSetConfig)]
}

@Observable
class CreateWorkoutViewModel {

    // MARK: - Form State

    var name: String = ""
    var iconName: String? = nil
    var categories: Set<String> = []
    var sets: Int = 8 {
        didSet { syncPerSetConfigs() }
    }
    var workSeconds: Int = 20
    var restSeconds: Int = 10
    var prepareSeconds: Int = 10
    var bellSoundOverride: String? = nil    // nil = use app default
    var countdownOverride: Bool? = nil      // nil = use app default
    let defaultBellSoundName: String          // for Default option preview
    let defaultCountdownEnabled: Bool         // for Default option display

    // Per-set configs, parallel array indexed 0..<sets
    var perSetConfigs: [PerSetConfig] = []

    // Repeat blocks, referenced by PerSetConfig.blockIndex
    var blocks: [WorkoutBlock] = []

    /// A new workout starts with these as row placeholders: a short sample workout, the same every time.
    static let sampleExercises = ["Jumping jacks", "Squats", "Push-ups", "Plank"]

    // MARK: - UI State

    var showCustomCategoryAlert: Bool = false
    var customCategoryInput: String = ""

    func toggleCategory(_ cat: String) {
        if categories.contains(cat) { categories.remove(cat) } else { categories.insert(cat) }
    }
    var validationError: String? = nil

    // MARK: - Edit Mode

    private let editingWorkout: Workout?

    var isEditMode: Bool { editingWorkout != nil }

    // MARK: - Init

    init(workout: Workout? = nil, settings: AppSettings? = nil) {
        self.editingWorkout = workout
        self.defaultBellSoundName = settings?.bellSoundName ?? "boxing_bell"
        self.defaultCountdownEnabled = settings?.countdownEnabled ?? true

        if let w = workout {
            name = w.name
            iconName = w.iconName
            categories = Set(w.category.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            sets = w.sets
            workSeconds = w.workSeconds
            restSeconds = w.restSeconds
            prepareSeconds = w.prepareSeconds
            bellSoundOverride = w.bellSoundName
            countdownOverride = w.countdownEnabled
            blocks = w.blocks

            let sorted = w.intervals.sorted { $0.setIndex < $1.setIndex }
            perSetConfigs = (0..<w.sets).map { i in
                let interval = sorted.first(where: { $0.setIndex == i })
                return PerSetConfig(
                    label: interval?.label ?? "",
                    workSecondsOverride: interval?.workSecondsOverride,
                    restSecondsOverride: interval?.restSecondsOverride,
                    blockIndex: interval?.blockIndex
                )
            }
        } else {
            workSeconds = settings?.defaultWorkSeconds ?? 20
            restSeconds = settings?.defaultRestSeconds ?? 10
            prepareSeconds = settings?.defaultPrepareSeconds ?? 10
            perSetConfigs = Self.sampleExercises.map { PerSetConfig(placeholder: $0) }
            sets = perSetConfigs.count
        }
    }

    // MARK: - Per-Set Config Sync

    private func syncPerSetConfigs() {
        if sets > perSetConfigs.count {
            perSetConfigs.append(contentsOf: (perSetConfigs.count..<sets).map { _ in PerSetConfig() })
        } else if sets < perSetConfigs.count {
            perSetConfigs = Array(perSetConfigs.prefix(sets))
        }
        normalizeBlocks()
    }

    func deleteSet(id: UUID) {
        guard sets > 1, let index = perSetConfigs.firstIndex(where: { $0.id == id }) else { return }
        perSetConfigs.remove(at: index)
        sets -= 1
    }

    /// Empties the list (rows and blocks) to build from scratch.
    func clearSets() {
        perSetConfigs = []
        blocks = []
        sets = 0
    }

    /// True when clearing would discard something the user entered.
    var hasSetContent: Bool {
        !blocks.isEmpty || perSetConfigs.contains(where: \.hasContent)
    }

    // MARK: - Repeat Blocks

    var setGroups: [SetGroup] {
        var groups: [SetGroup] = []
        for row in perSetConfigs.enumerated() {
            if let last = groups.last, last.blockIndex == row.element.blockIndex {
                groups[groups.count - 1].rows.append(row)
            } else {
                groups.append(SetGroup(id: row.element.id, blockIndex: row.element.blockIndex, rows: [row]))
            }
        }
        return groups
    }

    func addSet() {
        sets += 1
    }

    func addBlock() {
        blocks.append(WorkoutBlock(rounds: 3, restBetweenRoundsSeconds: 60))
        perSetConfigs.append(PerSetConfig(blockIndex: blocks.count - 1))
        sets = perSetConfigs.count
    }

    func addSet(toBlock block: Int) {
        let end = (perSetConfigs.lastIndex { $0.blockIndex == block } ?? perSetConfigs.count - 1) + 1
        perSetConfigs.insert(PerSetConfig(blockIndex: block), at: end)
        sets = perSetConfigs.count
    }

    /// Deletes a block together with its rows.
    func deleteBlock(_ block: Int) {
        perSetConfigs.removeAll { $0.blockIndex == block }
        sets = perSetConfigs.count  // syncPerSetConfigs prunes the emptied block and renumbers the rest
    }

    func blockHasContent(_ block: Int) -> Bool {
        perSetConfigs.contains { $0.blockIndex == block && $0.hasContent }
    }

    /// Moves a row to `index` (counted without the row itself) and into `block` (nil = standalone).
    func moveSet(id: UUID, to index: Int, block: Int?) {
        guard let from = perSetConfigs.firstIndex(where: { $0.id == id }) else { return }
        var row = perSetConfigs.remove(at: from)
        row.blockIndex = block
        perSetConfigs.insert(row, at: min(index, perSetConfigs.count))
        normalizeBlocks()
    }

    /// Moves a block's rows together to `index` (counted without them).
    func moveBlock(_ block: Int, to index: Int) {
        let rows = perSetConfigs.filter { $0.blockIndex == block }
        perSetConfigs.removeAll { $0.blockIndex == block }
        perSetConfigs.insert(contentsOf: rows, at: min(index, perSetConfigs.count))
        normalizeBlocks()
    }

    /// Renumbers blocks in the order they appear, dropping blocks that lost all their rows.
    private func normalizeBlocks() {
        var order: [Int] = []  // old block indexes, by first appearance
        for case let b? in perSetConfigs.map(\.blockIndex) where blocks.indices.contains(b) && !order.contains(b) {
            order.append(b)
        }
        blocks = order.map { blocks[$0] }
        for i in perSetConfigs.indices {
            perSetConfigs[i].blockIndex = perSetConfigs[i].blockIndex.flatMap { order.firstIndex(of: $0) }
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && workSeconds > 0 && sets > 0
    }

    // MARK: - Save

    func save(context: ModelContext) {
        guard isValid else { return }

        if let workout = editingWorkout {
            workout.name = name.trimmingCharacters(in: .whitespaces)
            workout.iconName = iconName
            workout.category = categories.sorted().joined(separator: ",")
            workout.sets = sets
            workout.workSeconds = workSeconds
            workout.restSeconds = restSeconds
            workout.prepareSeconds = prepareSeconds
            workout.bellSoundName = bellSoundOverride
            workout.countdownEnabled = countdownOverride
            workout.blocks = blocks
            workout.updatedAt = Date()

            for interval in workout.intervals {
                context.delete(interval)
            }
            workout.intervals = makeIntervals(for: workout, context: context)
        } else {
            let workout = Workout(
                name: name.trimmingCharacters(in: .whitespaces),
                iconName: iconName,
                category: categories.sorted().joined(separator: ","),
                sets: sets,
                workSeconds: workSeconds,
                restSeconds: restSeconds,
                prepareSeconds: prepareSeconds,
                bellSoundName: bellSoundOverride,
                countdownEnabled: countdownOverride
            )
            workout.blocks = blocks
            context.insert(workout)
            workout.intervals = makeIntervals(for: workout, context: context)
        }
    }

    // MARK: - AI Apply

    func applyGeneratedConfigs(_ generated: [GeneratedSetConfig]) {
        for (i, gen) in generated.enumerated() {
            guard perSetConfigs.indices.contains(i) else { break }
            perSetConfigs[i].label = gen.label
            if let work = gen.workSeconds { perSetConfigs[i].workSecondsOverride = work }
            if let rest = gen.restSeconds { perSetConfigs[i].restSecondsOverride = rest }
        }
    }

    // MARK: - Helpers

    private func makeIntervals(for workout: Workout, context: ModelContext) -> [WorkoutInterval] {
        perSetConfigs.enumerated().compactMap { (i, config) in
            let trimmed = config.label.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty || config.workSecondsOverride != nil || config.restSecondsOverride != nil
                || config.blockIndex != nil else { return nil }
            let interval = WorkoutInterval(
                setIndex: i,
                label: trimmed,
                workSecondsOverride: config.workSecondsOverride,
                restSecondsOverride: config.restSecondsOverride,
                blockIndex: config.blockIndex,
                workout: workout
            )
            context.insert(interval)
            return interval
        }
    }
}
