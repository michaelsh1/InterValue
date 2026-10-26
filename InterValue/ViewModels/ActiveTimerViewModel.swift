import Foundation
import UIKit

@Observable
@MainActor
final class ActiveTimerViewModel {

    // MARK: - Engine

    let engine = TimerEngine()

    // MARK: - Config

    private(set) var config: WorkoutConfiguration?

    // MARK: - Elapsed Tracking

    /// Set when the workout begins.
    private var startDate: Date?
    /// Set when the timer reaches .finish. Nil until then.
    private var finishDate: Date?

    /// Returns time from start to finish (or to now if not yet finished).
    /// Computed so the finish screen always shows the right value on first render,
    /// even before `onFinish()` locks in `finishDate`.
    var elapsedSeconds: Int {
        guard let start = startDate else { return 0 }
        return Int((finishDate ?? Date()).timeIntervalSince(start))
    }

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - UI State

    var showStopAlert: Bool = false


    // MARK: - Forwarded Engine State

    var currentPhase: TimerPhase         { engine.currentPhase }
    var remainingSeconds: Int            { engine.remainingSeconds }
    var progress: Double                 { engine.progress }
    var currentSetIndex: Int             { engine.currentSetIndex }
    var isPaused: Bool                   { engine.isPaused }
    var currentIntervalLabel: String     { engine.currentIntervalLabel }
    var totalSets: Int                   { config?.sets ?? 0 }
    var phaseStartWallTime: Date?        { engine.phaseStartWallTime }
    var totalSecondsInCurrentPhase: Int  { engine.totalSecondsInCurrentPhase }

    // MARK: - Lifecycle

    func onAppear(with config: WorkoutConfiguration) {
        guard self.config == nil else { return }    // guard against double-start
        self.config = config
        startDate = Date()
        UIApplication.shared.isIdleTimerDisabled = true
        engine.start(with: config)
    }

    /// Called by the view when phase transitions to .finish.
    func onFinish() {
        guard finishDate == nil else { return }
        finishDate = Date()
    }

    func onDisappear() {
        UIApplication.shared.isIdleTimerDisabled = false
        engine.stop()
    }

    // MARK: - Controls

    func togglePause() {
        if engine.isPaused { engine.resume() } else { engine.pause() }
    }

    func skip() {
        engine.skip()
    }

    func restartCurrentPhase() {
        engine.restartCurrentPhase()
    }

    func goBackToPreviousSamePhase() {
        engine.goBackToPreviousSamePhase()
    }

    /// Call when the user confirms the stop alert.
    func confirmStop() {
        finishDate = Date()
        engine.stop()
    }
}
