import Foundation

/// Lightweight struct passed to TimerEngine. Works for both saved and quickstart workouts.
struct WorkoutConfiguration {
    let workoutName: String
    let sets: Int
    let workSeconds: Int
    let restSeconds: Int
    let prepareSeconds: Int
    let bellSoundName: String
    let countdownEnabled: Bool
    let volume: Float
    let intervalLabels: [String]           // Per-set labels, may be empty
    let perSetWorkOverrides: [Int?]        // nil entry = use global workSeconds
    let perSetRestOverrides: [Int?]        // nil entry = use global restSeconds
    var blockPositions: [BlockPosition?] = []  // nil entry = not in a repeat block
}

/// Where a set sits inside a repeat block (all 1-based), for the timer's set counter.
struct BlockPosition {
    let round: Int
    let rounds: Int
    let exercise: Int
    let exercises: Int
}

struct WorkoutIcons {
    static let available: [String] = [
        // Body parts
        "body-part-six-pack", "body-part-muscle", "body-part-leg", "body-part-back-2", "body-weight",
        // Workout types
        "workout-run", "workout-squats", "workout-stretching", "workout-warm-up",
        "workout-battle-ropes", "workout-gymnastics", "workout-kicking", "workout-sport",
        // Equipment
        "dumbbell-01", "dumbbell-02", "dumbbell-03", "kettlebell",
        "pull-up-bar", "push-up-bar", "gymnastic-rings", "expander",
        "equipment-bench-press", "equipment-chest-press", "equipment-weightlifting",
        "skipping-rope", "treadmill-01", "running-shoes", "hand-grip",
        "boxing-bag", "boxing-glove", "punching-ball-01", "dips",
        // Yoga & flexibility
        "yoga-01", "yoga-mat", "wellness",
    ]
}

struct WorkoutCategories {
    static let defaults = [
        "All", "Abs", "Chest", "Arms", "Legs",
        "Back", "Shoulders", "Cardio", "Flexibility", "Custom"
    ]

    static func icon(for category: String) -> String? {
        switch category {
        case "Abs":         return "body-part-six-pack"
        case "Chest":       return "equipment-bench-press"
        case "Arms":        return "body-part-muscle"
        case "Legs":        return "body-part-leg"
        case "Back":        return "body-part-back-2"
        case "Shoulders":   return "equipment-weightlifting"
        case "Cardio":      return "workout-run"
        case "Flexibility": return "workout-stretching"
        default:            return nil
        }
    }
}
