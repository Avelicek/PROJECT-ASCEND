import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "YOUR PERSONAL SYSTEM", title: "Profile")
                PremiumCard {
                    HStack(spacing: AppSpacing.md) {
                        Text(String(store.profile.displayName.prefix(1)).uppercased()).font(.title.weight(.semibold))
                            .frame(width: 60, height: 60).background(AppColor.accent.opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.profile.displayName).accessibilityIdentifier("profile.name").font(.title3.weight(.semibold))
                            Text("Lifetime level \(store.lifetimeLevel) · \(store.rank.rank.title)").font(.caption).foregroundStyle(AppColor.muted)
                        }
                    }
                }
                PremiumCard {
                    VStack(spacing: AppSpacing.md) {
                        SectionHeader(title: "Goals & baseline")
                        goal("Current weight", store.progress.actualWeight.map { "\($0.formatted()) kg" } ?? "Not logged")
                        goal("Target weight", store.profile.targetWeightKG.map { "\($0.formatted()) kg" } ?? "Set a goal")
                        goal("Desired weekly pace", "\(store.profile.desiredWeeklyChangeKG.formatted()) kg")
                        goal("Daily energy", "\(Int(store.profile.calorieGoal).formatted()) kcal")
                        goal("Daily protein", "\(Int(store.profile.proteinGoal)) g")
                        goal("Sleep target", "\(store.profile.sleepTargetHours.formatted()) hours")
                        PrimaryAction(title: "Edit profile & goals", symbol: "slider.horizontal.3") { editing = true }
                    }
                }
                PrimaryAction(title: "Configure objectives", symbol: "scope") { store.presentedSheet = .objectives }
                PremiumCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Eyebrow(text: "LOCAL BY DESIGN")
                        Text("Your history lives on this iPhone.").font(.headline)
                        Text("No account. No cloud sync. Your metrics and scoring work offline. Optional on-device intelligence adds interpretation when available.")
                            .font(AppTypography.body).foregroundStyle(AppColor.muted)
                        PillStatus(title: store.settings.onDeviceAIEnabled ? "ON-DEVICE AI REQUESTED" : "DETERMINISTIC INTELLIGENCE")
                        Text("Appearance · Midnight\nRest timer preferences and additional themes arrive in Build 02.")
                            .font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                Text("ASCEND / BUILD 01").font(.caption2).tracking(2).foregroundStyle(AppColor.muted).frame(maxWidth: .infinity)
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.profile").featureBackground().sheet(isPresented: $editing) { NavigationStack { ProfileEditor(store: store).environment(store) }.preferredColorScheme(.dark) }
    }
    private func goal(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) { Text(label).foregroundStyle(AppColor.muted); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.subheadline)
    }
}
