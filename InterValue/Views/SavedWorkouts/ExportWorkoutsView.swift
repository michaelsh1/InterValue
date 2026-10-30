import SwiftUI

/// Sheet for selecting which workouts to export.
/// Produces a shareable deep-link URL via iOS share sheet.
struct ExportWorkoutsView: View {
    let allWorkouts: [Workout]
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<UUID>
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false

    init(allWorkouts: [Workout]) {
        self.allWorkouts = allWorkouts
        // Pre-select all by default
        _selected = State(initialValue: Set(allWorkouts.map { $0.id }))
    }

    private var selectedWorkouts: [Workout] {
        allWorkouts.filter { selected.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select which workouts to include in the shared link.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    // Select all / Deselect all toggle
                    Button {
                        if selected.count == allWorkouts.count {
                            selected = []
                        } else {
                            selected = Set(allWorkouts.map { $0.id })
                        }
                    } label: {
                        HStack {
                            Image(systemName: selected.count == allWorkouts.count
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(selected.count == allWorkouts.count
                                                 ? Color.accentColor : .secondary)
                            Text(selected.count == allWorkouts.count ? "Deselect All" : "Select All")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section("\(selected.count) of \(allWorkouts.count) selected") {
                    ForEach(allWorkouts) { workout in
                        Button {
                            if selected.contains(workout.id) {
                                selected.remove(workout.id)
                            } else {
                                selected.insert(workout.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected.contains(workout.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(selected.contains(workout.id)
                                                     ? Color.accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.name)
                                        .foregroundStyle(.primary)
                                        .font(.body)
                                    Text("\(workout.totalSets) sets · \(workout.totalDurationFormatted)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Export Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share Link") {
                        let dtos = selectedWorkouts.map { WorkoutDTO(workout: $0) }
                        shareURL = DeepLinkManager.exportURL(for: dtos)
                        showShareSheet = true
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }
}

// MARK: - UIActivityViewController wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
