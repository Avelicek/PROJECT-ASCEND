import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editing = false
    @State private var trainingProfile = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "OWNER", title: "Your system")
                PremiumCard(role: .hero, tint: AppColor.bodyweight) {
                    VStack(alignment: .leading, spacing: 18) {
                        Group {
                            if typeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 16) { identity; rankBadge } }
                            else { HStack(spacing: 12) { identity; Spacer(minLength: 0); rankBadge } }
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
                SectionHeader(title: "Training")
                PremiumCard(role: .glass) {
                    VStack(alignment: .leading, spacing: 6) {
                        settingsAction("My Gym · training profile", symbol: "dumbbell") { trainingProfile = true }.accessibilityIdentifier("profile.training")
                        Text("\(store.training.profile.resolvedEquipment.count) equipment types available").font(.caption2).foregroundStyle(AppColor.muted)
                    }
                }
                SectionHeader(title: "Intelligence")
                NavigationLink {
                    BrainSettingsView().environment(store)
                } label: {
                    settingsRow("Personal Brain", symbol: "waveform.path")
                }
                .buttonStyle(PremiumPressStyle())
                .accessibilityIdentifier("profile.brain")
                SectionHeader(title: "Goals")
                PremiumCard(role: .glass) {
                    VStack(alignment: .leading, spacing: 16) {
                        settingsAction("Profile & goals", symbol: "slider.horizontal.3") { editing = true }
                        HStack {
                            StatBlock(title: "Target weight", value: weight(store.profile.targetWeightKG), tint: AppColor.bodyweight)
                            StatBlock(title: "Weekly pace", value: "\(store.profile.desiredWeeklyChangeKG.formatted()) kg")
                        }
                        MetricStrip(metrics: [
                            GlanceMetric(title: "Energy · kcal", value: "\(Int(store.profile.calorieGoal).formatted())", symbol: "flame", tint: AppColor.nutrition),
                            GlanceMetric(title: "Protein · g", value: "\(Int(store.profile.proteinGoal))", symbol: "fork.knife", tint: AppColor.nutrition),
                            GlanceMetric(title: "Sleep · h", value: store.profile.sleepTargetHours.formatted(), symbol: "moon", tint: AppColor.sleep)
                        ])
                        settingsAction("Daily objectives", symbol: "scope") { store.presentedSheet = .objectives }
                    }
                }
                SectionHeader(title: "System")
                PremiumCard(role: .inline) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "lock.shield").foregroundStyle(AppColor.blue); Eyebrow(text: "LOCAL BY DESIGN") }
                        HStack { PillStatus(title: "OFFLINE", tint: AppColor.muted); PillStatus(title: "NO ACCOUNT", tint: AppColor.muted) }
                        Text(store.settings.onDeviceAIEnabled ? "On-device interpretation enabled" : "On-device interpretation off")
                            .font(.caption).foregroundStyle(AppColor.muted)
                        Toggle("Haptics", isOn: Binding(get: { store.settings.hapticsEnabled }, set: { enabled in _ = store.perform { store.settings.hapticsEnabled = enabled } })).font(.subheadline).tint(AppColor.accent)
                        Text("Your training and goals stay on this iPhone.").font(.caption2).foregroundStyle(AppColor.muted)
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.profile").featureBackground(tint: AppColor.bodyweight)
            .sheet(isPresented: $editing) { NavigationStack { ProfileEditor(store: store).environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $trainingProfile) { NavigationStack { TrainingProfileView().environment(store) }.preferredColorScheme(.dark) }
    }
    private var identity: some View {
        HStack(spacing: 12) {
            Text(String(store.profile.displayName.prefix(1)).uppercased())
                .font(.system(.largeTitle, design: .rounded, weight: .semibold)).frame(width: 62, height: 62)
                .background(AppColor.blue.opacity(0.12), in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(store.profile.displayName).accessibilityIdentifier("profile.name").font(.title2.weight(.semibold)).foregroundStyle(AppColor.text)
                PillStatus(title: "LEVEL \(store.lifetimeLevel)")
            }
        }
    }
    private var rankBadge: some View { RankBadgeView(rank: store.rank.rank, size: 108).accessibilityIdentifier("profile.rank.badge") }
    private func weight(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "—" }
    private func settingsRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(AppColor.bodyweight).frame(width: 24)
            Text(title).font(.subheadline).foregroundStyle(AppColor.secondary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(AppColor.muted)
        }
        .frame(minHeight: 48)
    }
    private func settingsAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { settingsRow(title, symbol: symbol) }.buttonStyle(PremiumPressStyle())
    }
}
