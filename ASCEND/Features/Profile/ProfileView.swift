import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false
    @State private var trainingProfile = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "OWNER", title: "Your system")
                PremiumCard(role: .hero, tint: AppColor.bodyweight) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            Text(String(store.profile.displayName.prefix(1)).uppercased())
                                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                .frame(width: 62, height: 62)
                                .background(LinearGradient(colors: [AppColor.blue.opacity(0.3), AppColor.accent.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                                .overlay(Circle().stroke(AppColor.blue.opacity(0.35))).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.profile.displayName).accessibilityIdentifier("profile.name").font(.title2.weight(.semibold))
                                PillStatus(title: "LEVEL \(store.lifetimeLevel)")
                            }
                            Spacer(minLength: 0)
                            RankBadgeView(rank: store.rank.rank, size: 108).accessibilityIdentifier("profile.rank.badge")
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Eyebrow(text: "CURRENT RANK")
                                Text(store.rank.rank.title).font(.title3.weight(.semibold)).foregroundStyle(AppColor.rank(store.rank.rank.tier))
                            }
                            Spacer()
                            StatBlock(title: "ELO", value: store.currentELO.formatted(), tint: AppColor.elo).frame(maxWidth: 90)
                        }
                        RankProgressView(status: store.rank)
                    }
                }
                PremiumCard(role: .action, tint: AppColor.bodyweight) {
                    VStack(spacing: 2) {
                        settingsAction("My Gym · training profile", symbol: "dumbbell") { trainingProfile = true }
                            .accessibilityIdentifier("profile.training")
                        Text(store.training.profile.resolvedEquipment.map(\.title).sorted().joined(separator: " · ")).font(.caption2).foregroundStyle(AppColor.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 10)
                        Rectangle().fill(AppColor.separator).frame(height: 1)
                        settingsAction("Profile & goals", symbol: "slider.horizontal.3") { editing = true }
                        Rectangle().fill(AppColor.separator).frame(height: 1)
                        settingsAction("Daily objectives", symbol: "scope") { store.presentedSheet = .objectives }
                    }
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "Direction")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 16)], alignment: .leading, spacing: 22) {
                            StatBlock(title: "Current", value: weight(store.progress.actualWeight), symbol: "scalemass", tint: AppColor.bodyweight)
                            StatBlock(title: "Target", value: weight(store.profile.targetWeightKG), symbol: "scope", tint: AppColor.blue)
                            StatBlock(title: "Weekly pace", value: "\(store.profile.desiredWeeklyChangeKG.formatted()) kg")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Daily foundation")
                    MetricStrip(metrics: [
                        GlanceMetric(title: "Energy · kcal", value: "\(Int(store.profile.calorieGoal).formatted())", symbol: "flame", tint: AppColor.nutrition),
                        GlanceMetric(title: "Protein · g", value: "\(Int(store.profile.proteinGoal))", symbol: "fork.knife", tint: AppColor.nutrition),
                        GlanceMetric(title: "Sleep · h", value: store.profile.sleepTargetHours.formatted(), symbol: "moon", tint: AppColor.sleep)
                    ])
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "lock.shield").foregroundStyle(AppColor.blue); Eyebrow(text: "LOCAL BY DESIGN") }
                        HStack { PillStatus(title: "OFFLINE"); PillStatus(title: "NO ACCOUNT", tint: AppColor.muted) }
                        Text(store.settings.onDeviceAIEnabled ? "On-device insights · local fallback available" : "Private insights on your iPhone")
                            .font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.profile").featureBackground(tint: AppColor.bodyweight)
            .sheet(isPresented: $editing) { NavigationStack { ProfileEditor(store: store).environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $trainingProfile) { NavigationStack { TrainingProfileView().environment(store) }.preferredColorScheme(.dark) }
    }
    private func weight(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "—" }
    private func settingsAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 12) { Image(systemName: symbol).foregroundStyle(AppColor.bodyweight).frame(width: 24); Text(title).font(.subheadline).foregroundStyle(AppColor.secondary); Spacer(); Image(systemName: "chevron.right").font(.caption2).foregroundStyle(AppColor.muted) }.frame(minHeight: 48) }.buttonStyle(PremiumPressStyle())
    }
}
