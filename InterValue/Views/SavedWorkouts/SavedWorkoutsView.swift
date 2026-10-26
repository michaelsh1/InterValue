import SwiftUI
import SwiftData

struct SavedWorkoutsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.createdAt, order: .reverse) private var allWorkouts: [Workout]
    @Query private var settingsQuery: [AppSettings]

    @State private var vm = SavedWorkoutsViewModel()
    @State private var showExport = false

    private var settings: AppSettings? { settingsQuery.first }
    private var favorites: [Workout] { vm.favoriteWorkouts(allWorkouts) }
    private var filtered: [Workout] { vm.filteredWorkouts(allWorkouts) }
    private var categories: [String] { vm.mergedCategories(from: allWorkouts) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Favorites section — hidden when none are favorited
                    if !favorites.isEmpty {
                        favoritesSection
                    }

                    // Presets header
                    presetsHeader

                    // Category filter chips
                    FilterChipBar(categories: categories, selected: $vm.selectedCategory)
                        .padding(.bottom, 8)

                    // Workout list
                    workoutList
                }
                .padding(.bottom, 88) // clearance above FAB
            }
            .background(Color(.systemGroupedBackground))

            // Floating "+" button
            addButton
        }
        .navigationTitle("Saved Workouts")
        .sheet(isPresented: $showExport) {
            ExportWorkoutsView(allWorkouts: allWorkouts)
        }
        .fullScreenCover(isPresented: $vm.showTimer) {
            if let config = vm.timerConfig {
                ActiveTimerView(config: config)
            }
        }
        .sheet(isPresented: $vm.showCreateSheet) {
            CreateWorkoutView(workout: vm.workoutToEdit, settings: settings)
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favorites) { workout in
                        FavoriteCardView(
                            workout: workout,
                            onTap:            { vm.start(workout, settings: settings) },
                            onEdit:           { vm.workoutToEdit = workout; vm.showCreateSheet = true },
                            onToggleFavorite: { vm.toggleFavorite(workout) },
                            onDuplicate:      { vm.duplicate(workout, context: modelContext) },
                            onDelete:         { modelContext.delete(workout) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Presets Header

    private var presetsHeader: some View {
        Text("Presets")
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    // MARK: - Workout List

    private var workoutList: some View {
        LazyVStack(spacing: 10) {
            if filtered.isEmpty {
                Text("No workouts in this category yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                ForEach(filtered) { workout in
                    WorkoutCardView(
                        workout: workout,
                        onStart:           { vm.start(workout, settings: settings) },
                        onEdit:            { vm.workoutToEdit = workout; vm.showCreateSheet = true },
                        onToggleFavorite:  { vm.toggleFavorite(workout) },
                        onDuplicate:       { vm.duplicate(workout, context: modelContext) },
                        onDelete:          { modelContext.delete(workout) }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Floating Add Button

    private var addButton: some View {
        Button {
            vm.workoutToEdit = nil
            vm.showCreateSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SavedWorkoutsView()
    }
    .modelContainer(for: [Workout.self, WorkoutInterval.self, AppSettings.self], inMemory: true)
}
