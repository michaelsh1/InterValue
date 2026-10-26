import SwiftUI
import SwiftData

struct QuickstartView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [AppSettings]

    @State private var vm = QuickstartViewModel()
    @State private var navRefreshID = UUID()

    private var settings: AppSettings? { settingsQuery.first }

    var body: some View {
        GeometryReader { proxy in
            Form {
                Section {
                    SetsSlider(title: "SETS", sets: $vm.sets)
                    DualTimePicker(title: "WORK", totalSeconds: $vm.workSeconds)
                    DualTimePicker(title: "REST", totalSeconds: $vm.restSeconds)
                }
            }
            .scrollDisabled(true)
            .contentMargins(
                .top,
                max(0, (proxy.size.height - 360 - 90) / 2),
                for: .scrollContent
            )
            .safeAreaInset(edge: .bottom) {
                actionBar
                    .padding(.bottom, 24)
                    .padding(.top, 8)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .ignoresSafeArea(.keyboard)
        .id(navRefreshID)
        .navigationTitle("Quickstart")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            vm.loadDefaults(from: settings)
        }
        .alert("Save Workout", isPresented: $vm.showSaveAlert) {
            TextField("Workout name", text: $vm.workoutName)
            Button("Save") {
                vm.saveWorkout(context: modelContext, settings: settings)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for this workout.")
        }
        .fullScreenCover(isPresented: $vm.showTimer, onDismiss: {
            navRefreshID = UUID()
        }) {
            ActiveTimerView(config: vm.buildConfiguration(settings: settings))
        }
    }

    // MARK: - Subviews

    private var actionBar: some View {
        HStack(spacing: 12) {
            // Circular save button
            Button {
                vm.workoutName = ""
                vm.showSaveAlert = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 54, height: 54)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(Circle())
            }

            // Pill-shaped start button
            Button {
                vm.showTimer = true
            } label: {
                Text("START")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        QuickstartView()
    }
    .modelContainer(for: [AppSettings.self, Workout.self], inMemory: true)
}
