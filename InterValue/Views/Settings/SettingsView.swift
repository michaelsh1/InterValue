import SwiftUI
import SwiftData

// MARK: - Entry point (resolves AppSettings from SwiftData)

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsResults: [AppSettings]

    var body: some View {
        if let settings = settingsResults.first {
            SettingsFormView(settings: settings)
        } else {
            ProgressView()
                .onAppear {
                    if settingsResults.isEmpty {
                        modelContext.insert(AppSettings())
                    }
                }
        }
    }
}

// MARK: - Main form (owns the ViewModel)

private struct SettingsFormView: View {
    @State private var vm: SettingsViewModel
    @State private var showAbout = false

    init(settings: AppSettings) {
        _vm = State(initialValue: SettingsViewModel(settings: settings))
    }

    var body: some View {
        let b = Bindable(vm)

        Form {
            soundSection(b)
            defaultTimersSection(b)
            colorsSection(b)
            workoutSection(b)
            appearanceSection(b)
            aboutSection
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Settings")
        .overlay {
            if showAbout {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showAbout = false } }

                AboutView()
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAbout)
    }

    // MARK: - Sound

    @ViewBuilder
    private func soundSection(_ b: Bindable<SettingsViewModel>) -> some View {
        Section("Sound") {
            Picker("Bell Sound", selection: b.bellSoundName) {
                ForEach(SettingsViewModel.soundOptions, id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .onChange(of: b.bellSoundName.wrappedValue) { _, newValue in
                let preview = SoundManager.variant("twice", of: newValue)
                SoundManager.shared.previewSound(soundName: preview, volume: vm.volume)
            }

            Toggle("Countdown", isOn: b.countdownEnabled)

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                Slider(value: b.volume, in: 0...1) { editing in
                    if !editing {
                        let preview = SoundManager.variant("twice", of: vm.bellSoundName)
                        SoundManager.shared.previewSound(soundName: preview, volume: vm.volume)
                    }
                }
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Workout

    @ViewBuilder
    private func workoutSection(_ b: Bindable<SettingsViewModel>) -> some View {
        Section("Active Workout View") {
            Toggle("Set Preview", isOn: b.showSetPreview)
            Toggle("Large Workout Text", isOn: b.largeWorkoutText)
        }
    }

    // MARK: - Default Timers

    @ViewBuilder
    private func defaultTimersSection(_ b: Bindable<SettingsViewModel>) -> some View {
        Section("Default Timers") {
            DualTimePicker(title: "WORK",    totalSeconds: b.defaultWorkSeconds)
            DualTimePicker(title: "REST",    totalSeconds: b.defaultRestSeconds)
            DualTimePicker(title: "PREPARE", totalSeconds: b.defaultPrepareSeconds)
        }
    }

    // MARK: - Colors

    @ViewBuilder
    private func colorsSection(_ b: Bindable<SettingsViewModel>) -> some View {
        Section("Colors") {
            PastelColorPicker(label: "Work",    selection: b.workColor)
            PastelColorPicker(label: "Rest",    selection: b.restColor)
            PastelColorPicker(label: "Prepare", selection: b.prepareColor)
            PastelColorPicker(label: "Finish",  selection: b.finishColor)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            Button("About") { showAbout = true }
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Appearance

    @ViewBuilder
    private func appearanceSection(_ b: Bindable<SettingsViewModel>) -> some View {
        Section("Appearance") {
            Picker("Theme", selection: b.theme) {
                Text("System").tag(AppTheme.system)
                Text("Light").tag(AppTheme.light)
                Text("Dark").tag(AppTheme.dark)
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - About

private struct AboutView: View {
    private let cornerRadius: CGFloat = 22

    var body: some View {
        VStack(spacing: 16) {
            Text("About")
                .font(.headline)
                .fontWeight(.semibold)

            Divider()
                .background(.white.opacity(0.4))

            Text("Why are you reading this about page and not working out?")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 280)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(uiColor: .secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.22), radius: 30, x: 0, y: 12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: AppSettings.self, inMemory: true)
}

