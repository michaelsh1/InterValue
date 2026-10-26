import Foundation
import SwiftData

@Model
class Workout {
    // Identity
    var id: UUID
    var name: String
    var category: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    // Timer Configuration
    var sets: Int
    var workSeconds: Int
    var restSeconds: Int
    var prepareSeconds: Int

    // Workout Icon (nil = no icon)
    var iconName: String?

    // Sound Override (nil = use app default)
    var bellSoundName: String?

    // Countdown Override (nil = use app default)
    var countdownEnabled: Bool?

    // Per-Set Labels (ordered)
    @Relationship(deleteRule: .cascade)
    var intervals: [WorkoutInterval]

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        category: String = "Custom",
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sets: Int,
        workSeconds: Int,
        restSeconds: Int,
        prepareSeconds: Int,
        bellSoundName: String? = nil,
        countdownEnabled: Bool? = nil,
        intervals: [WorkoutInterval] = []
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.category = category
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sets = sets
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.prepareSeconds = prepareSeconds
        self.bellSoundName = bellSoundName
        self.countdownEnabled = countdownEnabled
        self.intervals = intervals
    }

    // MARK: - Computed Properties

    var totalDurationSeconds: Int {
        let workTotal = sets * workSeconds
        let restTotal = (sets - 1) * restSeconds  // No rest after the last set
        return prepareSeconds + workTotal + restTotal
    }

    var totalDurationFormatted: String {
        let mins = totalDurationSeconds / 60
        let secs = totalDurationSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
