import SwiftUI

struct DashboardNutritionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    private var calories: Double { store.todayNutrition?.calories ?? 0 }
    private var protein: Double { store.todayNutrition?.proteinGrams ?? 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                SectionHeader(title: "Daily fuel")
                Button("Log") { store.presentedSheet = .nutrition }.font(.subheadline.weight(.medium)).frame(minWidth: 44, minHeight: 44)
            }
            PremiumCard {
                Group {
                    if typeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: AppSpacing.lg) { calorieRing; proteinDetail } }
                    else { HStack(spacing: AppSpacing.lg) { calorieRing; proteinDetail } }
                }
            }
        }
    }
    private var calorieRing: some View {
        ZStack {
            ProgressRing(progress: calories / max(1, store.profile.calorieGoal), tint: AppColor.accent)
            VStack(spacing: 3) {
                Text(store.todayNutrition == nil ? "—" : calories.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit().contentTransition(.numericText())
                Text("KCAL").font(.system(.caption2, weight: .medium)).tracking(1.4).foregroundStyle(AppColor.muted)
            }
        }.frame(width: 116, height: 116).accessibilityElement(children: .ignore)
            .accessibilityLabel("Calories").accessibilityValue("\(Int(calories)) of \(Int(store.profile.calorieGoal)) kilocalories")
    }
    private var proteinDetail: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Eyebrow(text: "DAILY ENERGY")
                Text("\(Int(store.profile.calorieGoal).formatted()) kcal target").font(.caption).foregroundStyle(AppColor.muted)
            }
            Rectangle().fill(AppColor.separator).frame(height: 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Protein").font(.subheadline)
                    Spacer(minLength: 6)
                    Text("\(Int(protein)) / \(Int(store.profile.proteinGoal)) g").font(.caption).foregroundStyle(AppColor.muted).monospacedDigit()
                }
                LinearProgress(progress: protein / max(1, store.profile.proteinGoal), tint: AppColor.violet)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct DashboardInsightView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        PremiumCard(accented: true) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(AppColor.accent)
                    Eyebrow(text: "ASCEND INTELLIGENCE")
                    Spacer()
                }
                DisclosureGroup {
                    Text(store.insight.summary).font(.subheadline).foregroundStyle(AppColor.muted).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                } label: {
                    Text(store.insight.headline).font(.system(.headline, weight: .semibold)).foregroundStyle(AppColor.text)
                }
                HStack {
                    PillStatus(title: store.insight.source == .onDevice ? "ON-DEVICE AI" : "LOCAL INSIGHT").accessibilityIdentifier("brain.source").accessibilityValue(store.insight.source.rawValue)
                    Text("\(store.insight.confidence.rawValue.capitalized) confidence").font(.caption2).foregroundStyle(AppColor.muted)
                }
            }
        }
    }
}
