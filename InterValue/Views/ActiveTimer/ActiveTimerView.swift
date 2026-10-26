import SwiftUI
import SwiftData
import UIKit

struct ActiveTimerView: View {

    let config: WorkoutConfiguration

    @Environment(\.dismiss) private var dismiss
    @Query private var settingsQuery: [AppSettings]
    @State private var vm = ActiveTimerViewModel()

    @GestureState private var isBackPressed = false
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>? = nil

    private var settings: AppSettings? { settingsQuery.first }
    private var largeWorkoutText: Bool {
        UserDefaults.standard.object(forKey: "largeWorkoutText") as? Bool ?? false
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            ZStack {
                phaseBackground
                if vm.currentPhase == .finish {
                    finishScreen
                } else if isLandscape {
                    landscapeTimerScreen
                } else {
                    portraitTimerScreen
                }
            }
            .overlay(alignment: .topLeading) {
                if vm.currentPhase != .finish {
                    Button {
                        vm.showStopAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.80))
                            .frame(width: 44, height: 44)
                    }
                    .padding(.top, proxy.safeAreaInsets.top + 52)
                    .padding(.leading, 16)
                    .opacity(controlsVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: controlsVisible)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in resetHideTimer() }
            )
        }
        .ignoresSafeArea()
        .onAppear {
            vm.onAppear(with: config)
            AppDelegate.allowLandscape = true
            resetHideTimer()
        }
        .onDisappear {
            vm.onDisappear()
        }
        .onChange(of: vm.currentPhase) { _, phase in
            if phase == .finish { vm.onFinish() }
        }
        .alert("Stop Workout?", isPresented: $vm.showStopAlert) {
            Button("Stop", role: .destructive) {
                AppDelegate.allowLandscape = false
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
                vm.confirmStop()
                dismiss()
            }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Your progress will not be saved.")
        }
        .statusBarHidden(true)
    }

    // MARK: - Controls Auto-Hide

    private func resetHideTimer() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) { controlsVisible = true }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) { controlsVisible = false }
            }
        }
    }

    // MARK: - Background

    private var phaseBackground: some View {
        phaseColor
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: vm.currentPhase)
    }

    // MARK: - Shared Display Computation

    private func computeDisplay(at date: Date) -> (progress: Double, seconds: Int) {
        guard !vm.isPaused, let start = vm.phaseStartWallTime else {
            let total = max(1, vm.totalSecondsInCurrentPhase)
            return (Double(vm.remainingSeconds) / Double(total), vm.remainingSeconds)
        }
        let total = vm.totalSecondsInCurrentPhase
        guard total > 0 else { return (1.0, 0) }
        let elapsed = date.timeIntervalSince(start)
        let secs = max(0, total - Int(elapsed))
        return (Double(secs) / Double(total), secs)
    }

    // MARK: - Portrait Timer Screen

    private var portraitTimerScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(phaseLabel)
                .font(largeWorkoutText ? .system(size: 52, weight: .bold) : .title.weight(.bold))
                .foregroundStyle(.white)
                .tracking(phaseLabelTracking)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.5)
                .animation(.easeInOut(duration: 0.2), value: phaseLabel)

            Spacer().frame(height: 36)

            TimelineView(.animation) { tl in
                let (ringProgress, displaySeconds) = computeDisplay(at: tl.date)
                ZStack {
                    PhaseProgressRing(progress: ringProgress, color: .white, lineWidth: 14)
                        .frame(width: 270, height: 270)
                        .animation(.linear(duration: 1), value: ringProgress)

                    Text(String(format: "%d:%02d", displaySeconds / 60, displaySeconds % 60))
                        .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeInOut(duration: 0.25), value: displaySeconds)
                }
            }

            Spacer().frame(height: 20)

            Text(setCounterText)
                .font(largeWorkoutText ? .title.weight(.semibold) : .title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.70))

            if vm.currentPhase == .work,
               UserDefaults.standard.object(forKey: "showSetPreview") as? Bool ?? true,
               let next = nextSetLabel {
                VStack(spacing: 2) {
                    Text("Next")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.60))
                        .textCase(.uppercase)
                        .tracking(2)
                    Text(next)
                        .font(largeWorkoutText ? .title.weight(.bold) : .title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.6)
                }
                .padding(.top, 4)
            }

            Spacer()

            controlsBar
                .padding(.bottom, 48)
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: controlsVisible)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Landscape Timer Screen

    private var landscapeTimerScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Phase / interval label — same font as portrait
            Text(phaseLabel)
                .font(largeWorkoutText ? .system(size: 52, weight: .bold) : .title.weight(.bold))
                .foregroundStyle(.white)
                .tracking(phaseLabelTracking)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.5)
                .animation(.easeInOut(duration: 0.2), value: phaseLabel)

            Spacer().frame(height: 14)

            // Time + progress bar driven by wall clock
            TimelineView(.animation) { tl in
                let (progress, displaySeconds) = computeDisplay(at: tl.date)
                VStack(spacing: 14) {
                    Text(String(format: "%d:%02d", displaySeconds / 60, displaySeconds % 60))
                        .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeInOut(duration: 0.25), value: displaySeconds)

                    // Horizontal progress bar
                    GeometryReader { barProxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.25))
                            Capsule()
                                .fill(.white)
                                .frame(width: barProxy.size.width * progress)
                        }
                    }
                    .frame(height: 14)
                    .animation(.linear(duration: 1), value: progress)
                }
            }
            .padding(.horizontal, 60)

            Spacer().frame(height: 14)

            Text(setCounterText)
                .font(largeWorkoutText ? .title.weight(.semibold) : .title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.70))

            if vm.currentPhase == .work,
               UserDefaults.standard.object(forKey: "showSetPreview") as? Bool ?? true,
               let next = nextSetLabel {
                VStack(spacing: 2) {
                    Text("Next")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.60))
                        .textCase(.uppercase)
                        .tracking(2)
                    Text(next)
                        .font(largeWorkoutText ? .title.weight(.bold) : .title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.6)
                }
                .padding(.top, 4)
            }

            Spacer()

            landscapeControlsBar
                .padding(.bottom, 28)
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: controlsVisible)
        }
    }

    private var landscapeControlsBar: some View {
        HStack(spacing: 36) {
            Button {
                vm.restartCurrentPhase()
            } label: {
                Image(systemName: "backward.end.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(isBackPressed ? 0.4 : 0.80))
                    .animation(.easeInOut(duration: 0.1), value: isBackPressed)
            }
            .highPriorityGesture(TapGesture(count: 2).onEnded {
                vm.goBackToPreviousSamePhase()
            })
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isBackPressed) { _, state, _ in state = true }
            )

            Button {
                vm.togglePause()
            } label: {
                Image(systemName: vm.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }

            Button {
                vm.skip()
            } label: {
                Image(systemName: "forward.end.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.80))
            }
        }
    }

    // MARK: - Finish Screen

    private var finishScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white)

            Spacer().frame(height: 24)

            Text("DONE")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .tracking(6)

            Spacer().frame(height: 20)

            Text(vm.elapsedFormatted)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text("total time")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(3)
                .padding(.top, 4)

            Spacer()

            Button {
                AppDelegate.allowLandscape = false
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
                dismiss()
            } label: {
                Text("Dismiss")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.white.opacity(0.20))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack {
            // Back — single tap restarts current phase, double tap goes to previous
            Button {
                vm.restartCurrentPhase()
            } label: {
                Image(systemName: "backward.end.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(isBackPressed ? 0.4 : 0.80))
                    .animation(.easeInOut(duration: 0.1), value: isBackPressed)
            }
            .highPriorityGesture(TapGesture(count: 2).onEnded {
                vm.goBackToPreviousSamePhase()
            })
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isBackPressed) { _, state, _ in state = true }
            )

            Spacer()

            // Pause / Resume (largest — primary action)
            Button {
                vm.togglePause()
            } label: {
                Image(systemName: vm.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Skip
            Button {
                vm.skip()
            } label: {
                Image(systemName: "forward.end.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.80))
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Computed Helpers

    private var phaseLabel: String {
        switch vm.currentPhase {
        case .prepare: return "PREPARE"
        case .work:    return vm.currentIntervalLabel.isEmpty ? "WORK" : vm.currentIntervalLabel.uppercased()
        case .rest:
            let showNextUp = UserDefaults.standard.object(forKey: "showSetPreview") as? Bool ?? true
            if showNextUp, let next = nextSetLabel { return next.uppercased() }
            return "REST"
        case .finish:  return "DONE"
        }
    }

    private var phaseLabelTracking: CGFloat {
        switch vm.currentPhase {
        case .prepare: return 6
        case .work:    return vm.currentIntervalLabel.isEmpty ? 6 : 2
        case .rest:
            let showNextUp = UserDefaults.standard.object(forKey: "showSetPreview") as? Bool ?? true
            return (showNextUp && nextSetLabel != nil) ? 2 : 6
        case .finish:  return 6
        }
    }

    private var setCounterText: String {
        switch vm.currentPhase {
        case .prepare:       "Get Ready"
        case .work, .rest:   "Set \(vm.currentSetIndex + 1) of \(vm.totalSets)"
        case .finish:        ""
        }
    }

    private var nextSetLabel: String? {
        guard vm.currentPhase == .work || vm.currentPhase == .rest else { return nil }
        let nextIndex = vm.currentSetIndex + 1
        guard nextIndex < vm.totalSets else { return nil }
        let label = config.intervalLabels.indices.contains(nextIndex) ? config.intervalLabels[nextIndex] : ""
        return label.isEmpty ? nil : label
    }

    private var phaseColor: Color {
        switch vm.currentPhase {
        case .prepare: Color(hex: settings?.prepareColorHex ?? "#FF9500")
        case .work:    Color(hex: settings?.workColorHex    ?? "#FF3B30")
        case .rest:    Color(hex: settings?.restColorHex    ?? "#007AFF")
        case .finish:  Color(hex: settings?.finishColorHex  ?? "#FF2D55")
        }
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r, g, b: UInt64
        switch hex.count {
        case 3:  (r, g, b) = ((value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6:  (r, g, b) = (value >> 16,        value >> 8 & 0xFF,        value & 0xFF)
        default: (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255)
    }
}

// MARK: - Preview

#Preview {
    ActiveTimerView(config: WorkoutConfiguration(
        workoutName: "Preview Workout",
        sets: 4,
        workSeconds: 20,
        restSeconds: 10,
        prepareSeconds: 5,
        bellSoundName: "boxing_bell",
        countdownEnabled: true,
        volume: 1.0,
        intervalLabels: ["Crunches", "Leg Raises", "Plank", "Bicycle"],
        perSetWorkOverrides: [],
        perSetRestOverrides: []
    ))
    .modelContainer(for: [AppSettings.self], inMemory: true)
}
