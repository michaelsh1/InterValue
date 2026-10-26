import Foundation
import SwiftData

@Observable
class QuickstartViewModel {

    // MARK: - Timer Controls
    var sets: Int = 8
    var workSeconds: Int = 20
    var restSeconds: Int = 10

    // MARK: - Save Alert
    var showSaveAlert: Bool = false
    var workoutName: String = ""

    // MARK: - Timer Sheet
    var showTimer: Bool = false

    // MARK: - Load Defaults

    func loadDefaults(from settings: AppSettings?) {
        guard let settings else { return }
        workSeconds = settings.defaultWorkSeconds
        restSeconds = settings.defaultRestSeconds
    }

    // MARK: - Actions

    func saveWorkout(context: ModelContext, settings: AppSettings?) {
        let trimmed = workoutName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let workout = Workout(
            name: trimmed,
            category: "Custom",
            sets: sets,
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            prepareSeconds: settings?.defaultPrepareSeconds ?? 10
        )
        context.insert(workout)
        workoutName = ""
    }

    func buildConfiguration(settings: AppSettings?) -> WorkoutConfiguration {
        WorkoutConfiguration(
            workoutName: "Quickstart",
            sets: sets,
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            prepareSeconds: settings?.defaultPrepareSeconds ?? 10,
            bellSoundName: settings?.bellSoundName ?? "boxing_bell",
            countdownEnabled: settings?.countdownEnabled ?? true,
            volume: settings?.volume ?? 1.0,
            intervalLabels: [],
            perSetWorkOverrides: [],
            perSetRestOverrides: []
        )
    }
}
