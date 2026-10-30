import Foundation
import SwiftData

@Model
class WorkoutInterval {
    var id: UUID
    var setIndex: Int
    var label: String

    // Optional per-interval overrides (future extensibility)
    // For v1, all sets share the parent workout's work/rest durations.
    var workSecondsOverride: Int?
    var restSecondsOverride: Int?

    // Index into the parent workout's blocks (nil = not in a repeat block)
    var blockIndex: Int?

    @Relationship
    var workout: Workout?

    init(
        id: UUID = UUID(),
        setIndex: Int,
        label: String,
        workSecondsOverride: Int? = nil,
        restSecondsOverride: Int? = nil,
        blockIndex: Int? = nil,
        workout: Workout? = nil
    ) {
        self.id = id
        self.setIndex = setIndex
        self.label = label
        self.workSecondsOverride = workSecondsOverride
        self.restSecondsOverride = restSecondsOverride
        self.blockIndex = blockIndex
        self.workout = workout
    }
}
