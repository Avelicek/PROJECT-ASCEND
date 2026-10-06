import SwiftUI

struct WorkoutView: View {
    @Environment(AppStore.self) private var store
    private var sets: Int { store.sessions.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.count } } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "PUT IN THE WORK", title: "Training")
                PremiumCard(accented: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 9) {
                                Eyebrow(text: "TRAINING CONSOLE")
                                Text("One session\ncloser.").font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                Text("Build strength. Earn your next rank.").font(.caption).foregroundStyle(AppColor.muted)
                            }
                            Spacer(minLength: 8)
                            ZStack {
                                Circle().stroke(AppColor.blue.opacity(0.12), lineWidth: 1)
                                Circle().trim(from: 0.05, to: 0.75).stroke(AppColor.blue.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round)).padding(8)
                                Image(systemName: "dumbbell.fill").font(.system(size: 38)).foregroundStyle(AppColor.blue)
                            }.frame(width: 88, height: 88).accessibilityHidden(true)
                        }
                        HStack {
                            StatBlock(title: "Sessions", value: "\(store.sessions.count)", symbol: "bolt.fill", tint: AppColor.blue)
                            StatBlock(title: "Sets logged", value: "\(sets)", symbol: "square.stack", tint: AppColor.accent)
                        }
                        PrimaryAction(title: "Log a workout", symbol: "plus") { store.presentedSheet = .workout }
                    }
                }
                SectionHeader(title: "Recent sessions", detail: "\(store.sessions.count) total")
                if store.sessions.isEmpty {
                    EmptyStateCard(symbol: "dumbbell", title: "Your first session awaits.", detail: "Choose an exercise and log your sets.")
                }
                ForEach(store.sessions.prefix(20), id: \.id) { session in WorkoutSessionCard(session: session) }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.workout").featureBackground()
    }
}

private struct WorkoutSessionCard: View {
    let session: WorkoutSession
    private var focus: [String] { Array(Set(session.exercises.flatMap { $0.contributions.map { $0.muscle.group } })).sorted() }
    private var workingSets: Int { session.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmup }.count } }
    private var volume: Double {
        session.exercises.filter { $0.trackingMode == .weightAndReps || $0.trackingMode == .reps }.reduce(0) { total, entry in
            total + WorkoutEngine().volume(entry.sets.filter { !$0.isWarmup }.map(\.performance))
        }
    }
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title).font(.headline)
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                    PillStatus(title: session.isQuickLog ? "QUICK" : "FULL")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { ForEach(focus, id: \.self) { PillStatus(title: $0.uppercased(), tint: AppColor.muted) } }
                }
                HStack {
                    StatBlock(title: "Working sets", value: "\(workingSets)")
                    if volume > 0 { StatBlock(title: "Volume", value: "\(Int(volume).formatted()) kg", tint: AppColor.blue) }
                }
                ForEach(session.exercises.sorted { $0.order < $1.order }, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(entry.exerciseName).font(.subheadline.weight(.medium))
                        ForEach(Array(entry.sets.sorted { $0.order < $1.order }.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text(String(format: "%02d", index + 1)).font(.caption2).foregroundStyle(AppColor.muted)
                                    .frame(width: 27, height: 27).background(AppColor.elevated, in: RoundedRectangle(cornerRadius: 7))
                                Text(setDescription(set, mode: entry.trackingMode)).font(.subheadline.weight(.medium)).monospacedDigit()
                                Spacer()
                                if set.isWarmup { Text("WARM-UP").font(.caption2).foregroundStyle(AppColor.muted) }
                                else { Image(systemName: "checkmark").font(.caption).foregroundStyle(AppColor.positive).accessibilityHidden(true) }
                            }.accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
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
