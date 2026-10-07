import SwiftUI

struct WorkoutView: View {
    @Environment(AppStore.self) private var store
    @State private var showRecords = false
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
                                Text("Build your\nnext level.").font(.system(.title, design: .rounded, weight: .semibold))
                            }
                            Spacer(minLength: 8)
                            ZStack {
                                Circle().stroke(AppColor.blue.opacity(0.12), lineWidth: 1)
                                Circle().trim(from: 0.05, to: 0.75).stroke(AppColor.blue.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round)).padding(8)
                                Image(systemName: "dumbbell.fill").font(.system(size: 38)).foregroundStyle(AppColor.blue)
                            }.frame(width: 88, height: 88).accessibilityHidden(true)
                        }
                        MetricStrip(metrics: [
                            GlanceMetric(title: "Sessions", value: "\(store.sessions.count)", symbol: "bolt.fill"),
                            GlanceMetric(title: "Sets logged", value: "\(sets)", symbol: "square.stack", tint: AppColor.accent),
                            GlanceMetric(title: "Records", value: "\(store.records.count)", symbol: "trophy", tint: AppColor.warning)
                        ])
                        PrimaryAction(title: store.activeWorkout == nil ? "Start workout" : "Resume workout", symbol: "play.fill") { store.startLiveWorkout() }
                            .accessibilityIdentifier("workout.start")
                        HStack {
                            Button("Log previous workout") { store.presentedSheet = .workout }
                            Spacer()
                            Button("PR history") { showRecords = true }
                        }.font(.caption).frame(minHeight: 44)
                    }
                }
                SectionHeader(title: "Recent sessions", detail: "\(store.sessions.count) total")
                if store.sessions.isEmpty {
                    EmptyStateCard(symbol: "dumbbell", title: "Your first session awaits.", detail: "Choose an exercise and log your sets.")
                }
                ForEach(store.sessions.prefix(20), id: \.id) { session in WorkoutSessionCard(session: session) }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.workout").featureBackground()
            .sheet(isPresented: $showRecords) { NavigationStack { RecordHistoryView().environment(store) }.preferredColorScheme(.dark) }
    }
}

private struct WorkoutSessionCard: View {
    let session: WorkoutSession
    private var snapshot: SessionSnapshot { SessionSnapshot(session: session) }
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
                HStack {
                    StatBlock(title: "Working sets", value: "\(snapshot.workingSets)")
                    if snapshot.volumeKG > 0 { StatBlock(title: "Volume", value: "\(Int(snapshot.volumeKG).formatted()) kg", tint: AppColor.blue) }
                    if let rpe = snapshot.exertion { StatBlock(title: "Avg RPE", value: rpe.formatted(.number.precision(.fractionLength(1))), tint: AppColor.warning) }
                }
                if !snapshot.focus.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "SET FOCUS")
                        ForEach(snapshot.focus.prefix(3)) { focus in
                            HStack(spacing: 10) {
                                Text(focus.group).font(.caption).foregroundStyle(AppColor.muted).frame(width: 68, alignment: .leading)
                                LinearProgress(progress: focus.share, tint: AppColor.blue, height: 4)
                                Text(focus.share.formatted(.percent.precision(.fractionLength(0)))).font(.caption2).monospacedDigit().frame(width: 32, alignment: .trailing)
                            }
                        }
                    }.padding(12).background(AppColor.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
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
                                else if let rpe = set.perceivedExertion { Text("RPE \(rpe.formatted())").font(.caption2).foregroundStyle(AppColor.blue) }
                                else { Image(systemName: "checkmark").font(.caption).foregroundStyle(AppColor.positive).accessibilityHidden(true) }
                            }.padding(.vertical, 5).padding(.horizontal, 8)
                                .background(AppColor.elevated.opacity(index.isMultiple(of: 2) ? 0.32 : 0.08), in: RoundedRectangle(cornerRadius: 10))
                                .accessibilityElement(children: .combine)
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
