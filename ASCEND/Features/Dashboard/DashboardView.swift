import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var appeared = false
    @State private var showScore = false
    @State private var showDaily = false
    @State private var showLatestResult = false
    @State private var keptObjectives: Set<String> = []
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                RankHeroView(showScore: $showScore)
                quickMetrics
                readinessAndMomentum
                DailyCommandCard { showLatestResult = false; showDaily = true }
                objectives
                DashboardNutritionView()
                DashboardInsightView()
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
                .opacity(appeared || AppMotion.snapshotMode ? 1 : 0).offset(y: appeared || reduceMotion || AppMotion.snapshotMode ? 0 : 10)
        }.accessibilityIdentifier("screen.dashboard").featureBackground().scrollIndicators(.hidden)
            .onAppear { withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reveal) { appeared = true } }
            .sheet(isPresented: $showScore) { NavigationStack { ScoreBreakdownView().environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $showDaily, onDismiss: { store.acknowledgeEvaluation() }) {
                NavigationStack { DailyEvaluationView(preferFinalized: showLatestResult).environment(store) }.preferredColorScheme(.dark)
            }
            .onChange(of: store.unseenEvaluation, initial: true) { _, unseen in if unseen { showLatestResult = true; showDaily = true } }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("ASCEND").font(.system(.title2, design: .rounded, weight: .bold)).tracking(4)
                Text("Your ascent, \(store.profile.displayName).")
                    .font(.system(.subheadline, weight: .medium)).foregroundStyle(AppColor.muted)
            }
            Spacer()
            Button { store.presentedSheet = .weight } label: {
                Image(systemName: "plus").font(.system(.headline, weight: .medium))
                    .foregroundStyle(AppColor.text).frame(width: 44, height: 44)
                    .background(LinearGradient(colors: [AppColor.accent.opacity(0.4), AppColor.blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .overlay { Circle().strokeBorder(AppColor.accent.opacity(0.4)) }
            }.buttonStyle(PremiumPressStyle()).accessibilityLabel("Log body weight")
        }.padding(.top, AppSpacing.lg)
            .overlay(alignment: .bottomLeading) {
                if store.isDemo { Text("DEMO").font(.system(size: 8, weight: .bold)).tracking(1.4).accessibilityIdentifier("demo.marker").foregroundStyle(AppColor.warning).offset(y: 14) }
            }
    }
    private var readinessAndMomentum: some View {
        Group {
            if typeSize.isAccessibilitySize { VStack(spacing: AppSpacing.md) { readinessCard; momentumCard } }
            else { HStack(alignment: .top, spacing: AppSpacing.sm) { readinessCard; momentumCard } }
        }
    }
    private var quickMetrics: some View {
        MetricStrip(metrics: [
            GlanceMetric(title: "Weight · kg", value: store.progress.actualWeight.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—", symbol: "scalemass"),
            GlanceMetric(title: "Sleep · h", value: store.todaySleep.map { $0.durationHours.formatted(.number.precision(.fractionLength(1))) } ?? "—", symbol: "moon", tint: AppColor.violet),
            GlanceMetric(title: "Sessions · 7D", value: String(store.sessions.filter { $0.startedAt >= store.policy.adding(days: -6, to: store.policy.start(of: store.now)) && $0.startedAt <= store.now }.count), symbol: "dumbbell", tint: AppColor.positive)
        ])
    }
    private var readinessCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "READINESS")
                ReadinessGauge(percent: store.readiness.percent, size: 70).frame(maxWidth: .infinity)
                Text(store.readiness.state?.rawValue.capitalized ?? "Log to discover").font(.caption.weight(.medium)).foregroundStyle(AppColor.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var momentumCard: some View {
        MomentumCard(report: store.progress)
    }
    private var objectives: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                let done = store.todayObjectives.filter { $0.completedAt != nil || $0.recoveryExempt }.count
                ZStack {
                    ProgressRing(progress: Double(done) / Double(max(1, store.todayObjectives.count)), tint: AppColor.positive, lineWidth: 3)
                    Text("\(done)").font(.caption2.weight(.semibold))
                }.frame(width: 29, height: 29).accessibilityLabel("\(done) of \(store.todayObjectives.count) objectives complete or recovery protected")
                SectionHeader(title: "Today's objectives")
                Button { store.presentedSheet = .objectives } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44).foregroundStyle(AppColor.muted)
                }.accessibilityLabel("Manage objectives")
            }
            if store.todayObjectives.isEmpty {
                Button { store.presentedSheet = .objectives } label: {
                    EmptyStateCard(symbol: "scope", title: "Set your daily rhythm.", detail: "Add a training, fuel or habit goal.")
                }.buttonStyle(PremiumPressStyle())
            } else {
                ForEach(store.todayObjectives, id: \.occurrenceKey) { occurrence in
                    ObjectiveRow(occurrence: occurrence) {
                        AppHaptics.tap(enabled: store.settings.hapticsEnabled)
                        switch ObjectiveKind(rawValue: occurrence.kindRaw) {
                        case .calories, .protein: store.presentedSheet = .nutrition
                        case .bodyWeight: store.presentedSheet = .weight
                        case .workout, .exercise: store.startLiveWorkout()
                        default:
                            if store.toggleObjective(occurrence) { AppHaptics.success(enabled: store.settings.hapticsEnabled) }
                        }
                    }
                    if !keptObjectives.contains(occurrence.occurrenceKey), let alternative = store.recoveryAlternative(for: occurrence) {
                        PremiumCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Eyebrow(text: "RECOVERY ALTERNATIVE")
                                Text("\(alternative.0) · \(Int(alternative.1.rounded()))% estimated recovery").font(.subheadline.weight(.medium))
                                HStack {
                                    Button("Recovery day") { if store.chooseRecoveryAlternative(occurrence) { AppHaptics.success(enabled: store.settings.hapticsEnabled) } }
                                    Spacer()
                                    Button("Keep objective") { keptObjectives.insert(occurrence.occurrenceKey) }
                                }.font(.caption.weight(.semibold)).frame(minHeight: 44)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("Dashboard · populated") {
    if let store = try? PreviewData.makeStore() { NavigationStack { DashboardView().environment(store) }.preferredColorScheme(.dark) }
    else { Text("Preview store could not be opened") }
}
#Preview("Dashboard · large text", traits: .sizeThatFitsLayout) {
    if let store = try? PreviewData.makeStore() {
        NavigationStack { DashboardView().environment(store) }.environment(\.dynamicTypeSize, .accessibility2).preferredColorScheme(.dark)
    }
}
