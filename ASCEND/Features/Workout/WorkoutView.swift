import SwiftUI

struct WorkoutView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "PUT IN THE WORK", title: "Training")
                PremiumCard(accented: true) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Image(systemName: "dumbbell").font(.largeTitle).foregroundStyle(AppColor.blue)
                        Text("One session closer.").font(.title2.weight(.semibold))
                        Text("Quick reps or every working set. Your training feeds your progression and recovery.")
                            .font(AppTypography.body).foregroundStyle(AppColor.muted)
                        PrimaryAction(title: "Log a workout", symbol: "plus") { store.presentedSheet = .workout }
                    }
                }
                SectionHeader(title: "Recent sessions", detail: "\(store.sessions.count) total")
                if store.sessions.isEmpty {
                    EmptyStateCard(symbol: "figure.strengthtraining.traditional", title: "Start your training history.", detail: "Choose from the built-in exercise library. No setup work required.")
                }
                ForEach(store.sessions.prefix(20), id: \.id) { session in
                    PremiumCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack { Text(session.title).font(.headline); Spacer(); PillStatus(title: session.isQuickLog ? "QUICK" : "FULL") }
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(AppColor.muted)
                            ForEach(session.exercises.sorted { $0.order < $1.order }, id: \.id) { entry in
                                ForEach(entry.sets.sorted { $0.order < $1.order }, id: \.id) { set in
                                    Text(setDescription(set, mode: entry.trackingMode)).font(.subheadline).monospacedDigit()
                                }
                            }
                        }
                    }
                }
                Text("Live sessions and rest timers arrive in Build 02.").font(.caption).foregroundStyle(AppColor.muted)
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.workout").featureBackground()
    }
    private func setDescription(_ set: WorkoutSet, mode: TrackingMode) -> String {
        switch mode {
        case .reps: "\(set.reps) reps" + (set.weightKG > 0 ? " · +\(set.weightKG.formatted()) kg" : "")
        case .weightAndReps: "\(set.weightKG.formatted()) kg × \(set.reps)"
        case .duration: "\((set.durationSeconds / 60).formatted(.number.precision(.fractionLength(0...1)))) min"
        case .distance: "\((set.distanceMeters / 1000).formatted()) km · \(Int(set.durationSeconds / 60)) min"
        }
    }
}
