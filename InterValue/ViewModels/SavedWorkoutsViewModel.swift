import Foundation
import SwiftData

@Observable
class SavedWorkoutsViewModel {

    // MARK: - Filter State
    var selectedCategory: String = "All"

    // MARK: - Sheet / Cover Presentation
    var showCreateSheet: Bool = false
    var workoutToEdit: Workout? = nil
    var showTimer: Bool = false
    var timerConfig: WorkoutConfiguration? = nil


    // MARK: - Derived Collections

    func favoriteWorkouts(_ workouts: [Workout]) -> [Workout] {
        workouts.filter { $0.isFavorite }
    }

    func filteredWorkouts(_ workouts: [Workout]) -> [Workout] {
        guard selectedCategory != "All" else { return workouts }
        let knownSet = Set(WorkoutCategories.defaults)
        return workouts.filter { workout in
            let cats = workout.category.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if selectedCategory == "Custom" {
                return cats.contains("Custom") || cats.contains(where: { !knownSet.contains($0) })
            }
            return cats.contains(selectedCategory)
        }
    }

    func mergedCategories(from workouts: [Workout]) -> [String] {
        WorkoutCategories.defaults
    }

    // MARK: - Actions

    func start(_ workout: Workout, settings: AppSettings?) {
        timerConfig = buildConfig(from: workout, settings: settings)
        showTimer = true
    }

    func buildConfig(from workout: Workout, settings: AppSettings?) -> WorkoutConfiguration {
        let sorted = workout.intervals.sorted { $0.setIndex < $1.setIndex }
        let labels = sorted.map { $0.label }
        let workOverrides: [Int?] = (0..<workout.sets).map { i in sorted.first { $0.setIndex == i }?.workSecondsOverride ?? nil }
        let restOverrides: [Int?] = (0..<workout.sets).map { i in sorted.first { $0.setIndex == i }?.restSecondsOverride ?? nil }
        return WorkoutConfiguration(
            workoutName: workout.name,
            sets: workout.sets,
            workSeconds: workout.workSeconds,
            restSeconds: workout.restSeconds,
            prepareSeconds: workout.prepareSeconds,
            bellSoundName: workout.bellSoundName ?? settings?.bellSoundName ?? "boxing_bell",
            countdownEnabled: workout.countdownEnabled ?? settings?.countdownEnabled ?? true,
            volume: settings?.volume ?? 1.0,
            intervalLabels: labels,
            perSetWorkOverrides: workOverrides,
            perSetRestOverrides: restOverrides
        )
    }

    func toggleFavorite(_ workout: Workout) {
        workout.isFavorite.toggle()
        workout.updatedAt = Date()
    }

    func duplicate(_ workout: Workout, context: ModelContext) {
        let copy = Workout(
            name: workout.name + " (Copy)",
            category: workout.category,
            isFavorite: false,
            sets: workout.sets,
            workSeconds: workout.workSeconds,
            restSeconds: workout.restSeconds,
            prepareSeconds: workout.prepareSeconds,
            bellSoundName: workout.bellSoundName
        )
        let copiedIntervals = workout.intervals.map {
            WorkoutInterval(setIndex: $0.setIndex, label: $0.label)
        }
        copy.intervals = copiedIntervals
        context.insert(copy)
    }

}
