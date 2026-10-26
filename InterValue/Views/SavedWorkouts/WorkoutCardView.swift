import SwiftUI

struct WorkoutCardView: View {
    let workout: Workout
    let onStart: () -> Void
    let onEdit: () -> Void
    let onToggleFavorite: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var showSetBreakdown = false
    @State private var showDeleteConfirmation = false
    @State private var didCopyBreakdown = false
    @State private var breakdownBounce = false

    var body: some View {
        cardContent
        .confirmationDialog(
            "Delete \"\(workout.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout will be permanently removed.")
        }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 12) {
            // Info column
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let icon = workout.iconName {
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.primary)
                    }
                    Text(workout.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                if hasCustomIntervals {
                    HStack(spacing: 0) {
                        Text("Sets \(workout.sets)  |  ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            showSetBreakdown = true
                        } label: {
                            HStack(spacing: 3) {
                                Text("Sets breakdown")
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showSetBreakdown) {
                            setsBreakdownPopover
                        }
                    }
                } else {
                    Text("Sets \(workout.sets)  |  Work \(workLabel)  |  Rest \(restLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(workout.totalDurationFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }

            Spacer()

            // Actions column
            VStack(alignment: .trailing, spacing: 10) {
                // Star + Three-dot menu
                HStack(spacing: 0) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: workout.isFavorite ? "star.fill" : "star")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(workout.isFavorite ? .yellow : .secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(action: onDuplicate) {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }

                // Start pill
                Button(action: onStart) {
                    Text("Start")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Popover

    @ViewBuilder
    private var setsBreakdownPopover: some View {
        Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 10) {
            ForEach(breakdownRows) { row in
                GridRow {
                    Text(row.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .gridColumnAlignment(.leading)
                    Text("|").foregroundStyle(.tertiary)
                    Text("Work \(row.work)s")
                    Text("|").foregroundStyle(.tertiary)
                    Text("Rest \(row.rest)s")
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .opacity(didCopyBreakdown ? 0.3 : 1.0)
        .padding(16)
        .frame(maxWidth: UIScreen.main.bounds.width - 32)
        .scaleEffect(breakdownBounce ? 0.9 : 1.0)
        .contentShape(Rectangle())
        .overlay {
            if didCopyBreakdown {
                HStack(spacing: 4) {
                    Text("Copied")
                    Image(systemName: "checkmark")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .transition(.opacity)
            }
        }
        .onTapGesture { copyBreakdown() }
        .presentationCompactAdaptation(.popover)
    }

    private struct BreakdownRow: Identifiable {
        let id: Int
        let name: String
        let work: Int
        let rest: Int
    }

    private var breakdownRows: [BreakdownRow] {
        (0..<workout.sets).map { i in
            let interval = workout.intervals.first { $0.setIndex == i }
            let name: String = {
                if let lbl = interval?.label, !lbl.isEmpty { return lbl }
                return "Set \(i + 1)"
            }()
            return BreakdownRow(
                id: i,
                name: name,
                work: interval?.workSecondsOverride ?? workout.workSeconds,
                rest: interval?.restSecondsOverride ?? workout.restSeconds
            )
        }
    }

    // Plain-text copy: pad each column to its longest value so the `|` line up,
    // matching the aligned grid layout shown in the popover.
    private var breakdownCopyText: String {
        let rows = breakdownRows
        let nameWidth = rows.map { $0.name.count }.max() ?? 0
        let workWidth = rows.map { "Work \($0.work)s".count }.max() ?? 0
        return rows.map { row in
            let name = row.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let work = "Work \(row.work)s".padding(toLength: workWidth, withPad: " ", startingAt: 0)
            return "\(name) | \(work) | Rest \(row.rest)s"
        }.joined(separator: "\n")
    }

    private func copyBreakdown() {
        UIPasteboard.general.string = breakdownCopyText

        withAnimation(.easeOut(duration: 0.1)) { breakdownBounce = true }
        withAnimation(.easeInOut(duration: 0.2)) { didCopyBreakdown = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { breakdownBounce = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) { didCopyBreakdown = false }
        }
    }

    // MARK: - Helpers

    private var workLabel: String { rangeLabel(for: \.workSecondsOverride, default: workout.workSeconds) }
    private var restLabel: String { rangeLabel(for: \.restSecondsOverride, default: workout.restSeconds) }

    private func rangeLabel(for override: KeyPath<WorkoutInterval, Int?>, default fallback: Int) -> String {
        let values = (0..<workout.sets).map { i in
            workout.intervals.first { $0.setIndex == i }?[keyPath: override] ?? fallback
        }
        let lo = values.min() ?? fallback
        let hi = values.max() ?? fallback
        return lo == hi ? "\(lo)s" : "\(lo)–\(hi)s"
    }

    private var hasCustomIntervals: Bool {
        !workout.intervals.isEmpty
    }
}
