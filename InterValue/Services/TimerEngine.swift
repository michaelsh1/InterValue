import Foundation
import Observation

// MARK: - TimerPhase

enum TimerPhase {
    case prepare, work, rest, finish
}

// MARK: - TimerEngine

/// Drives the active workout timer. Pre-computes a flat phase sequence at start and
/// advances through it, using wall-clock time for resilience against background suspension.
@Observable
@MainActor
final class TimerEngine {

    // MARK: - Public State

    private(set) var currentPhase: TimerPhase = .prepare
    /// 0-based index of the current work set. Unchanged during prepare/rest/finish.
    private(set) var currentSetIndex: Int = 0
    private(set) var remainingSeconds: Int = 0
    /// Duration of the phase that is currently running. Used for progress calculation.
    private(set) var totalSecondsInCurrentPhase: Int = 0
    private(set) var isPaused: Bool = false
    private(set) var isRunning: Bool = false
    /// Label for the current work interval, or "" during prepare/rest/finish.
    private(set) var currentIntervalLabel: String = ""

    /// 1.0 when the phase just started, 0.0 when it is about to end.
    var progress: Double {
        guard totalSecondsInCurrentPhase > 0 else { return 1.0 }
        return Double(remainingSeconds) / Double(totalSecondsInCurrentPhase)
    }

    // MARK: - Private Types

    private typealias PhaseStep = (phase: TimerPhase, durationSeconds: Int, setIndex: Int)

    // MARK: - Private State

    private var workout: WorkoutConfiguration?
    private var phaseSequence: [PhaseStep] = []
    private var currentPhaseIndex: Int = 0
    private var timer: Timer?
    /// Wall-clock time at which the current phase started (back-dated when resuming from pause).
    private(set) var phaseStartWallTime: Date?

    // MARK: - Public API

    func start(with config: WorkoutConfiguration) {
        stop()
        workout = config
        phaseSequence = buildPhaseSequence(from: config)
        currentPhaseIndex = 0
        isRunning = true
        isPaused = false
        SoundManager.shared.preloadAll()
        SoundManager.shared.startBackgroundSession()
        enterCurrentPhase(playSound: false)
        scheduleTimer()
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        timer?.invalidate()
        timer = nil
        isPaused = true
        phaseStartWallTime = nil
        // remainingSeconds is kept as-is from the last tick
    }

    func resume() {
        guard isRunning, isPaused else { return }
        // Back-date phaseStartWallTime so the remaining count is preserved
        let elapsed = totalSecondsInCurrentPhase - remainingSeconds
        phaseStartWallTime = Date().addingTimeInterval(-TimeInterval(elapsed))
        isPaused = false
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        phaseStartWallTime = nil
        workout = nil
        SoundManager.shared.stopBackgroundSession()
    }

    /// Immediately skips the current phase and enters the next one.
    func skip() {
        guard isRunning else { return }
        advancePhase(elapsedBeyond: 0)
    }

    /// Restarts the current phase from the beginning.
    func restartCurrentPhase() {
        guard isRunning else { return }
        remainingSeconds = totalSecondsInCurrentPhase
        phaseStartWallTime = Date()
    }

    /// Double-tap back: goes to the previous phase in the sequence, whatever it is.
    /// rest[N] → work[N], work[N] → rest[N-1], work[0]/prepare → restart current.
    func goBackToPreviousSamePhase() {
        guard isRunning else { return }
        let prevIndex = currentPhaseIndex - 1
        guard prevIndex >= 0 else {
            restartCurrentPhase()
            return
        }
        currentPhaseIndex = prevIndex
        enterCurrentPhase(playSound: true)
    }

    // MARK: - Timer Scheduling

    private func scheduleTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.timerTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Tick

    private func timerTick() {
        guard isRunning, !isPaused else { return }

        let step = phaseSequence[currentPhaseIndex]

        if step.phase == .finish {
            complete()
            return
        }

        guard let startTime = phaseStartWallTime else { return }

        let elapsed = Int(Date().timeIntervalSince(startTime))
        let remaining = step.durationSeconds - elapsed

        if remaining > 0 {
            remainingSeconds = remaining
            playCountdownTickIfNeeded(remaining: remaining)
        } else {
            advancePhase(elapsedBeyond: -remaining)
        }
    }

    // MARK: - Phase Lifecycle

    private func enterCurrentPhase(playSound: Bool) {
        let step = phaseSequence[currentPhaseIndex]
        currentPhase = step.phase
        if step.setIndex >= 0 { currentSetIndex = step.setIndex }
        totalSecondsInCurrentPhase = step.durationSeconds
        remainingSeconds = step.durationSeconds
        currentIntervalLabel = labelForStep(step)
        phaseStartWallTime = step.phase != .finish ? Date() : nil

        if playSound { playTransitionSound() }
    }

    /// Advances past the current phase. `elapsedBeyond` is the number of seconds that
    /// overshot the boundary — used to fast-forward through phases that fully elapsed
    /// while the app was suspended in the background.
    private func advancePhase(elapsedBeyond: Int) {
        var overflow = elapsedBeyond

        while true {
            currentPhaseIndex += 1
            guard currentPhaseIndex < phaseSequence.count else {
                complete()
                return
            }

            let step = phaseSequence[currentPhaseIndex]

            if step.phase == .finish {
                playTransitionSound(isFinish: true)
                complete()
                return
            }

            if overflow < step.durationSeconds {
                currentPhase = step.phase
                if step.setIndex >= 0 { currentSetIndex = step.setIndex }
                totalSecondsInCurrentPhase = step.durationSeconds
                remainingSeconds = step.durationSeconds - overflow
                currentIntervalLabel = labelForStep(step)
                phaseStartWallTime = Date().addingTimeInterval(-TimeInterval(overflow))
                playTransitionSound()
                return
            }

            overflow -= step.durationSeconds
        }
    }

    private func complete() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        currentPhase = .finish
        remainingSeconds = 0
        totalSecondsInCurrentPhase = 0
        currentIntervalLabel = ""
        phaseStartWallTime = nil
        SoundManager.shared.stopBackgroundSession()
    }

    // MARK: - Sound

    private func playTransitionSound(isFinish: Bool = false) {
        guard let config = workout else { return }
        let variant: String
        if isFinish {
            variant = "thrice"
        } else if currentPhase == .rest {
            variant = "once"
        } else {
            variant = "twice"
        }
        let soundName = SoundManager.variant(variant, of: config.bellSoundName)
        SoundManager.shared.play(soundName: soundName, volume: config.volume)
    }

    private func playCountdownTickIfNeeded(remaining: Int) {
        guard let config = workout, config.countdownEnabled else { return }
        guard currentPhase == .work || currentPhase == .rest, remaining >= 1, remaining <= 3 else { return }
        let soundName = SoundManager.variant("once", of: config.bellSoundName)
        SoundManager.shared.play(soundName: soundName, volume: config.volume)
    }

    // MARK: - Phase Sequence Builder

    private func buildPhaseSequence(from config: WorkoutConfiguration) -> [PhaseStep] {
        var seq: [PhaseStep] = []

        if config.prepareSeconds > 0 {
            seq.append((.prepare, config.prepareSeconds, -1))
        }

        for i in 0..<config.sets {
            let workSecs = config.perSetWorkOverrides.indices.contains(i) ? (config.perSetWorkOverrides[i] ?? config.workSeconds) : config.workSeconds
            seq.append((.work, workSecs, i))
            if i < config.sets - 1 {
                let restSecs = config.perSetRestOverrides.indices.contains(i) ? (config.perSetRestOverrides[i] ?? config.restSeconds) : config.restSeconds
                seq.append((.rest, restSecs, i))
            }
        }

        seq.append((.finish, 0, -1))
        return seq
    }

    // MARK: - Helpers

    private func labelForStep(_ step: PhaseStep) -> String {
        guard step.phase == .work, step.setIndex >= 0 else { return "" }
        let labels = workout?.intervalLabels ?? []
        guard !labels.isEmpty, step.setIndex < labels.count else { return "" }
        return labels[step.setIndex]
    }
}
