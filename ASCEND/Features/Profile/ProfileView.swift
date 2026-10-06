import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "YOUR PERSONAL SYSTEM", title: "Identity hub")
                PremiumCard(accented: true) {
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
                            StatBlock(title: "ELO", value: "\(store.currentELO)").frame(maxWidth: 90)
                        }
                        RankProgressView(status: store.rank)
                    }
                }
                HStack { Eyebrow(text: "CONTROL CENTER"); Spacer(); Text("Personal targets").font(.caption2).foregroundStyle(AppColor.muted) }
                PrimaryAction(title: "Edit profile & goals", symbol: "slider.horizontal.3") { editing = true }
                PrimaryAction(title: "Configure objectives", symbol: "scope") { store.presentedSheet = .objectives }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "Body & direction", detail: "BASELINE")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 16)], alignment: .leading, spacing: 22) {
                            StatBlock(title: "Current", value: weight(store.progress.actualWeight), symbol: "scalemass")
                            StatBlock(title: "Target", value: weight(store.profile.targetWeightKG), symbol: "scope", tint: AppColor.blue)
                            StatBlock(title: "Weekly pace", value: "\(store.profile.desiredWeeklyChangeKG.formatted()) kg")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Daily foundation")
                    MetricStrip(metrics: [
                        GlanceMetric(title: "Energy · kcal", value: "\(Int(store.profile.calorieGoal).formatted())", symbol: "flame", tint: AppColor.warning),
                        GlanceMetric(title: "Protein · g", value: "\(Int(store.profile.proteinGoal))", symbol: "fork.knife", tint: AppColor.positive),
                        GlanceMetric(title: "Sleep · h", value: store.profile.sleepTargetHours.formatted(), symbol: "moon", tint: AppColor.accent)
                    ])
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "lock.shield").foregroundStyle(AppColor.blue); Eyebrow(text: "LOCAL BY DESIGN") }
                        Text("Your history. Your iPhone.").font(.headline)
                        HStack { PillStatus(title: "OFFLINE"); PillStatus(title: "NO ACCOUNT", tint: AppColor.muted) }
                        Text(store.settings.onDeviceAIEnabled ? "On-device insights requested. Local fallback stays available." : "Local insights · deterministic scoring")
                            .font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.profile").featureBackground()
            .sheet(isPresented: $editing) { NavigationStack { ProfileEditor(store: store).environment(store) }.preferredColorScheme(.dark) }
    }
    private func weight(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "—" }
}
