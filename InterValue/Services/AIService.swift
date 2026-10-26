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

        let raw: GeneratedWorkout
        do {
            let session = LanguageModelSession(instructions: instructions)
            raw = try await session.respond(to: prompt, generating: GeneratedWorkout.self).content
        } catch let error as LanguageModelSession.GenerationError {
            print("[AIService] generation error: \(error)")
            if case .guardrailViolation = error { throw AIServiceError.blocked }
            if case .refusal = error { throw AIServiceError.blocked }
            throw AIServiceError.failed
        } catch {
            print("[AIService] generation error: \(error)")
            throw AIServiceError.failed
        }

        let sets = raw.sets.map {
            GeneratedSetConfig(
                label: String($0.label.prefix(32)),
                workSeconds: generateTimes ? $0.workSeconds : nil,
                restSeconds: generateTimes ? $0.restSeconds : nil
            )
        }
        return GeneratedWorkout(name: String(raw.name.prefix(40)), categories: raw.categories, sets: sets)
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
