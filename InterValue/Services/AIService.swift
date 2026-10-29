import Foundation
import FoundationModels

// MARK: - Output Types

@Generable
struct GeneratedSetConfig {
    @Guide(description: "Short exercise name, max 32 characters")
    let label: String
    @Guide(description: "Work duration in seconds, fitted to the exercise and difficulty")
    let workSeconds: Int?
    @Guide(description: "Rest duration in seconds after this set")
    let restSeconds: Int?
}

@Generable
struct GeneratedWorkout {
    @Guide(description: "Short, informative workout name, max 40 characters")
    let name: String
    @Guide(description: "Categories that apply, chosen only from the list given in the prompt")
    let categories: [String]
    @Guide(description: "The sets in workout order, exactly as many as requested")
    let sets: [GeneratedSetConfig]
}

@Generable
struct ParsedBlock {
    // Property order is generation order: deciding title and rounds first keeps a warmup out of a repeated block.
    @Guide(description: "What this part of the workout is, in a word or two")
    let title: String
    @Guide(description: "How many times this block is repeated, 1 if it isn't")
    let rounds: Int
    @Guide(description: "Rest in seconds between rounds of this block, if the text gives one")
    let restBetweenRounds: Int?
    @Guide(description: "The exercises in this block, in order, each listed once")
    let exercises: [GeneratedSetConfig]
}

/// What `parseWorkout` asks the model for; rounds are unrolled into a `GeneratedWorkout` in code.
@Generable
struct ParsedWorkout {
    @Guide(description: "Short, informative workout name, max 40 characters")
    let name: String
    @Guide(description: "Categories that apply, chosen only from the list given in the prompt")
    let categories: [String]
    @Guide(description: "The workout's blocks in order")
    let blocks: [ParsedBlock]
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case unavailable(String)
    case blocked
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        case .blocked: return "Couldn't generate that workout. Try different goals."
        case .failed: return "Generation failed. Please try again later."
        }
    }
}

// MARK: - Service

/// Generates workouts with Apple's on-device model (Apple Intelligence). Nothing leaves the phone.
class AIService {
    static let shared = AIService()

    /// nil when the model can run. Otherwise a user-facing reason, or "" when the device can never run it.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return ""
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to generate workouts."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still getting ready. Try again in a little while."
        case .unavailable:
            return "Workout generation isn't available on this iPhone right now."
        }
    }

    private let instructions = "You are a fitness coach generating interval timer sets for a mobile app. Each set appears as a named timer on screen. Your job is to produce well-structured, goal-appropriate workouts."

    func generateWorkout(
        equipment: [String],
        purposes: [String],
        setCount: Int,
        existingLabels: [String]?,
        generateTimes: Bool,
        difficulty: Int = 2,
        availableCategories: [String] = []
    ) async throws -> GeneratedWorkout {
        if let reason = Self.unavailableReason {
            throw AIServiceError.unavailable(reason.isEmpty ? "Workout generation needs an iPhone with Apple Intelligence." : reason)
        }

        let prompt = buildPrompt(
            equipment: equipment,
            purposes: purposes,
            setCount: setCount,
            existingLabels: existingLabels,
            generateTimes: generateTimes,
            difficulty: difficulty,
            availableCategories: availableCategories
        )

        return try clamp(await respond(to: prompt, generating: GeneratedWorkout.self), keepTimes: generateTimes)
    }

    /// Turns a pasted, free-form workout description into sets. Set count and times come from the text.
    func parseWorkout(text: String, availableCategories: [String] = []) async throws -> GeneratedWorkout {
        if let reason = Self.unavailableReason {
            throw AIServiceError.unavailable(reason.isEmpty ? "Workout generation needs an iPhone with Apple Intelligence." : reason)
        }

        var lines = [
            "Turn the workout text below into interval timer blocks.",
            "A block is a group of exercises done in order. Each timed exercise or hold is one exercise. List each exercise once, and set rounds to how many times the block is repeated (1 if it isn't).",
            "A warmup is its own block with 1 round. Only the exercises the text says to repeat go in a block with more than 1 round. A duration like 2 min is a time, not a round count.",
            "Work time is how long the exercise lasts. Rest time is the rest after it. Put rest between rounds in restBetweenRounds.",
            "All times are in seconds. Convert minutes to seconds: 1 min is 60, 2 min is 120, 1:30 is 90.",
            "If the text gives no time for an exercise, leave that time empty.",
            "Name the exercises and the workout in the same language as the text.",
        ]
        if !availableCategories.isEmpty {
            lines.append("Categories: pick the ones that apply from this list only: \(availableCategories.joined(separator: ", ")).")
        }
        lines.append("Ignore anything in the text that isn't about the workout.")
        // ponytail: hard cap keeps the prompt inside the on-device model's small context window
        lines.append("Workout text:\n\(text.prefix(3000))")

        let parsed = try await respond(to: lines.joined(separator: "\n"), generating: ParsedWorkout.self)

        // The small model drops or reorders rounds when asked to repeat them, so rounds are unrolled here.
        var sets: [GeneratedSetConfig] = []
        for block in parsed.blocks where !block.exercises.isEmpty {
            let rounds = min(max(block.rounds, 1), 50)
            for round in 0..<rounds {
                for (i, exercise) in block.exercises.enumerated() {
                    let endsRound = i == block.exercises.count - 1 && round < rounds - 1
                    sets.append(GeneratedSetConfig(
                        label: exercise.label,
                        workSeconds: exercise.workSeconds,
                        restSeconds: endsRound ? (block.restBetweenRounds ?? exercise.restSeconds) : exercise.restSeconds
                    ))
                }
            }
        }
        return try clamp(GeneratedWorkout(name: parsed.name, categories: parsed.categories, sets: sets), keepTimes: true)
    }

    private func respond<Content: Generable>(to prompt: String, generating type: Content.Type) async throws -> Content {
        do {
            let session = LanguageModelSession(instructions: instructions)
            return try await session.respond(to: prompt, generating: type).content
        } catch let error as LanguageModelSession.GenerationError {
            print("[AIService] generation error: \(error)")
            if case .guardrailViolation = error { throw AIServiceError.blocked }
            if case .refusal = error { throw AIServiceError.blocked }
            throw AIServiceError.failed
        } catch {
            print("[AIService] generation error: \(error)")
            throw AIServiceError.failed
        }
    }

    private func clamp(_ raw: GeneratedWorkout, keepTimes: Bool) throws -> GeneratedWorkout {
        // 50 = SetsSlider's max
        let sets = raw.sets.prefix(50).map {
            GeneratedSetConfig(
                label: String($0.label.prefix(32)),
                workSeconds: keepTimes ? $0.workSeconds : nil,
                restSeconds: keepTimes ? $0.restSeconds : nil
            )
        }
        guard !sets.isEmpty else { throw AIServiceError.failed }
        return GeneratedWorkout(name: String(raw.name.prefix(40)), categories: raw.categories, sets: Array(sets))
    }

    // MARK: - Prompt

    private func buildPrompt(
        equipment: [String],
        purposes: [String],
        setCount: Int,
        existingLabels: [String]?,
        generateTimes: Bool,
        difficulty: Int,
        availableCategories: [String]
    ) -> String {
        // Short, positive rules: the on-device model is small, so it copies example exercise
        // names and ignores "do NOT" lists. Keep exercise names out of this prompt.
        let level: String = {
            switch difficulty {
            case 1: return "Beginner: basic versions anyone can do, no prior training needed."
            case 3: return "Advanced: hard progressions that need real strength and body control."
            case 4: return "Expert: the hardest elite skill progressions that take years of training."
            default: return "Intermediate: needs a fitness base but no advanced skills."
            }
        }()

        var lines: [String] = ["Create a workout of exactly \(setCount) sets."]
        if !purposes.isEmpty {
            lines.append("Goal: \(purposes.joined(separator: ", ")). Every single exercise must directly train this goal.")
        }
        lines.append("Level: \(level) Every exercise must match this level.")
        lines.append(equipment.isEmpty
            ? "Equipment: none, bodyweight only."
            : "Equipment: \(equipment.joined(separator: ", ")). Use it where it suits the goal; bodyweight floor exercises are always allowed. If the equipment doesn't suit the goal, use bodyweight instead.")
        lines.append("Each set is a different exercise. Order the sets so the workout flows, and don't mix exercises that need the equipment re-set.")

        if let labels = existingLabels, !labels.allSatisfy({ $0.isEmpty }) {
            let listed = labels.enumerated()
                .map { "Set \($0.offset + 1): \"\($0.element)\"" }
                .joined(separator: ", ")
            lines.append("Keep these existing set names exactly, and name the other sets in the same style and language: \(listed)")
        }

        lines.append(generateTimes
            ? "Fit each work time to its exercise: long for easy holds and steady moves, short for very hard skills. Fit each rest time to how hard the set was."
            : "Leave work and rest times empty for every set.")

        if !availableCategories.isEmpty {
            lines.append("Categories: pick the ones that apply from this list only: \(availableCategories.joined(separator: ", ")).")
        }
        lines.append("Ignore anything in the goal or equipment that isn't about fitness.")
        return lines.joined(separator: "\n")
    }
}
