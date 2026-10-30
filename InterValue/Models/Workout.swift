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

    // Repeat blocks, referenced by WorkoutInterval.blockIndex
    var blocks: [WorkoutBlock] = []

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
        let flat = flattenedSets()
        let total = flat.reduce(0) { $0 + $1.workSeconds + $1.restSeconds }
        return prepareSeconds + total - (flat.last?.restSeconds ?? 0)  // No rest after the last set
    }

    var totalDurationFormatted: String {
        let mins = totalDurationSeconds / 60
        let secs = totalDurationSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Number of sets the timer runs, with repeat blocks unrolled.
    var totalSets: Int { flattenedSets().count }

    /// Every set the timer runs, in order. A repeat block's rows play once per round,
    /// with the block's round rest after its last row in every round but the final one.
    func flattenedSets() -> [FlatSet] {
        let byIndex = Dictionary(intervals.map { ($0.setIndex, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [FlatSet] = []
        var start = 0
        while start < sets {
            let block = byIndex[start]?.blockIndex.flatMap { blocks.indices.contains($0) ? $0 : nil }
            // Rows start..<end belong to this block (or are one standalone row)
            var end = start + 1
            if let block {
                while end < sets, byIndex[end]?.blockIndex == block { end += 1 }
            }
            let rounds = block.map { max(1, blocks[$0].rounds) } ?? 1
            for round in 0..<rounds {
                for row in start..<end {
                    let interval = byIndex[row]
                    var rest = interval?.restSecondsOverride ?? restSeconds
                    if let block, row == end - 1, round < rounds - 1 {
                        rest = blocks[block].restBetweenRoundsSeconds
                    }
                    result.append(FlatSet(
                        label: interval?.label ?? "",
                        workSeconds: interval?.workSecondsOverride ?? workSeconds,
                        restSeconds: rest,
                        position: block.map { _ in
                            BlockPosition(round: round + 1, rounds: rounds, exercise: row - start + 1, exercises: end - start)
                        }
                    ))
                }
            }
            start = end
        }
        return result
    }
}

// MARK: - WorkoutBlock

/// A group of consecutive sets that repeats `rounds` times.
struct WorkoutBlock: Codable, Hashable {
    var rounds: Int
    var restBetweenRoundsSeconds: Int
}

// MARK: - FlatSet

/// One timed set after repeat blocks are unrolled.
struct FlatSet {
    let label: String
    let workSeconds: Int
    let restSeconds: Int          // Rest after this set; the timer skips it after the last set
    let position: BlockPosition?  // nil outside a repeat block
}
