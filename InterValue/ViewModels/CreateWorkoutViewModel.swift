import Foundation
import Observation
import SwiftData

struct PerSetConfig {
    var label: String = ""
    var workSecondsOverride: Int? = nil
    var restSecondsOverride: Int? = nil
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

            let sorted = w.intervals.sorted { $0.setIndex < $1.setIndex }
            perSetConfigs = (0..<w.sets).map { i in
                let interval = sorted.first(where: { $0.setIndex == i })
                return PerSetConfig(
                    label: interval?.label ?? "",
                    workSecondsOverride: interval?.workSecondsOverride,
                    restSecondsOverride: interval?.restSecondsOverride
                )
            }
        } else {
            workSeconds = settings?.defaultWorkSeconds ?? 20
            restSeconds = settings?.defaultRestSeconds ?? 10
            prepareSeconds = settings?.defaultPrepareSeconds ?? 10
            perSetConfigs = Array(repeating: PerSetConfig(), count: sets)
        }
    }

    // MARK: - Per-Set Config Sync

    private func syncPerSetConfigs() {
        if sets > perSetConfigs.count {
            perSetConfigs.append(contentsOf: Array(repeating: PerSetConfig(), count: sets - perSetConfigs.count))
        } else if sets < perSetConfigs.count {
            perSetConfigs = Array(perSetConfigs.prefix(sets))
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && workSeconds > 0
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
            guard !trimmed.isEmpty || config.workSecondsOverride != nil || config.restSecondsOverride != nil else { return nil }
            let interval = WorkoutInterval(
                setIndex: i,
                label: trimmed,
                workSecondsOverride: config.workSecondsOverride,
                restSecondsOverride: config.restSecondsOverride,
                workout: workout
            )
            context.insert(interval)
            return interval
        }
    }
}
