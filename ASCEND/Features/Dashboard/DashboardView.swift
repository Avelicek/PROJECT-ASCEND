import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var appeared = false
    @State private var showScore = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                RankHeroView(showScore: $showScore)
                readinessAndMomentum
                objectives
                DashboardNutritionView()
                DashboardInsightView()
                Text("Built by your effort. Owned by you.")
                    .font(.caption2).foregroundStyle(AppColor.muted.opacity(0.7)).frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm)
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
                .opacity(appeared ? 1 : 0).offset(y: appeared || reduceMotion ? 0 : 10)
        }.accessibilityIdentifier("screen.dashboard").featureBackground().scrollIndicators(.hidden)
            .onAppear { withAnimation(reduceMotion ? nil : AppAnimation.reveal) { appeared = true } }
            .sheet(isPresented: $showScore) { NavigationStack { ScoreBreakdownView().environment(store) }.preferredColorScheme(.dark) }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "PROJECT ASCEND")
                Text("Your ascent, \(store.profile.displayName).")
                    .font(.system(.subheadline, weight: .medium)).foregroundStyle(AppColor.muted)
            }
            Spacer()
            Button { store.presentedSheet = .weight } label: {
                Image(systemName: "plus").font(.system(.headline, weight: .medium))
                    .foregroundStyle(AppColor.text).frame(width: 44, height: 44).background(AppColor.elevated, in: Circle())
            }.buttonStyle(PremiumPressStyle()).accessibilityLabel("Log body weight")
        }.padding(.top, AppSpacing.lg)
            .overlay(alignment: .bottomLeading) {
                if store.isDemo { Text("IN-MEMORY DEMO").font(.system(size: 8, weight: .bold)).tracking(1.4).accessibilityIdentifier("demo.marker").foregroundStyle(AppColor.warning).offset(y: 16) }
            }
    }
    private var readinessAndMomentum: some View {
        Group {
            if typeSize.isAccessibilitySize { VStack(spacing: AppSpacing.md) { readinessCard; momentumCard } }
            else { HStack(alignment: .top, spacing: AppSpacing.sm) { readinessCard; momentumCard } }
        }
    }
    private var readinessCard: some View {
        MetricCard(title: "BODY READINESS", value: store.readiness.percent.map { String(Int($0.rounded())) } ?? "—", suffix: "%",
            detail: store.readiness.state?.rawValue.uppercased() ?? "LOG TO DISCOVER", tint: AppColor.blue)
    }
    private var momentumCard: some View {
        MetricCard(title: "MOMENTUM · 7D", value: store.progress.momentumPercent.map { String(format: "%+.0f", $0) } ?? "—", suffix: "%",
            detail: store.progress.momentumPercent.map { $0 < 0 ? "DOWNGRADE" : $0 > 0 ? "PROGRESS" : "STEADY" } ?? "BUILDING BASELINE",
            tint: (store.progress.momentumPercent ?? 0) < 0 ? AppColor.warning : AppColor.positive)
    }
    private var objectives: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "Today's objectives", detail: "\(store.todayObjectives.filter { $0.completedAt != nil || $0.recoveryExempt }.count)/\(store.todayObjectives.count)")
                Button { store.presentedSheet = .objectives } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44).foregroundStyle(AppColor.muted)
                }.accessibilityLabel("Manage objectives")
            }
            if store.todayObjectives.isEmpty {
                Button { store.presentedSheet = .objectives } label: {
                    EmptyStateCard(symbol: "scope", title: "Choose what matters.", detail: "Build your own daily rhythm. Add a goal for nutrition, training or a small habit.")
                }.buttonStyle(PremiumPressStyle())
            } else {
                ForEach(store.todayObjectives, id: \.occurrenceKey) { occurrence in
                    ObjectiveRow(occurrence: occurrence) {
                        AppHaptics.tap(enabled: store.settings.hapticsEnabled)
                        switch ObjectiveKind(rawValue: occurrence.kindRaw) {
                        case .calories, .protein: store.presentedSheet = .nutrition
                        case .bodyWeight: store.presentedSheet = .weight
                        case .workout, .exercise: store.presentedSheet = .workout
                        default:
                            if store.toggleObjective(occurrence) { AppHaptics.success(enabled: store.settings.hapticsEnabled) }
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
