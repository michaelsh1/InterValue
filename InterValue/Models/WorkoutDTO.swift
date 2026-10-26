import Foundation
import SwiftData

// MARK: - WorkoutDTO
// Plain Codable structs used for deep-link export/import (JSON → Base64)

struct WorkoutDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var category: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var sets: Int
    var workSeconds: Int
    var restSeconds: Int
    var prepareSeconds: Int
    var bellSoundName: String?
    var countdownEnabled: Bool?
    var intervals: [WorkoutIntervalDTO]

    // MARK: - Init from SwiftData model
    init(workout: Workout) {
        self.id = workout.id
        self.name = workout.name
        self.category = workout.category
        self.isFavorite = false
        self.createdAt = workout.createdAt
        self.updatedAt = workout.updatedAt
        self.sets = workout.sets
        self.workSeconds = workout.workSeconds
        self.restSeconds = workout.restSeconds
        self.prepareSeconds = workout.prepareSeconds
        self.bellSoundName = workout.bellSoundName
        self.countdownEnabled = workout.countdownEnabled
        self.intervals = workout.intervals
            .sorted { $0.setIndex < $1.setIndex }
            .map { WorkoutIntervalDTO(interval: $0) }
    }

    // MARK: - Convert to SwiftData model
    @discardableResult
    func toWorkout(context: ModelContext) -> Workout {
        let workout = Workout(
            id: id,
            name: name,
            category: category,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sets: sets,
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            prepareSeconds: prepareSeconds,
            bellSoundName: bellSoundName,
            countdownEnabled: countdownEnabled
        )
        context.insert(workout)

        let workoutIntervals = intervals.map { dto -> WorkoutInterval in
            let interval = WorkoutInterval(
                id: dto.id,
                setIndex: dto.setIndex,
                label: dto.label,
                workSecondsOverride: dto.workSecondsOverride,
                restSecondsOverride: dto.restSecondsOverride,
                workout: workout
            )
            context.insert(interval)
            return interval
        }
        workout.intervals = workoutIntervals
        return workout
    }
}

// MARK: - WorkoutIntervalDTO

struct WorkoutIntervalDTO: Codable, Identifiable {
    var id: UUID
    var setIndex: Int
    var label: String
    var workSecondsOverride: Int?
    var restSecondsOverride: Int?

    init(interval: WorkoutInterval) {
        self.id = interval.id
        self.setIndex = interval.setIndex
        self.label = interval.label
        self.workSecondsOverride = interval.workSecondsOverride
        self.restSecondsOverride = interval.restSecondsOverride
    }

}
