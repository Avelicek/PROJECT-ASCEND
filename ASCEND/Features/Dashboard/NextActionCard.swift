import SwiftUI

struct NextActionCard: View {
    @Environment(AppStore.self) private var store
    let showDaily: () -> Void
    private var next: NextActionPresentation { store.nextAction }
    private var tint: Color {
        switch next.kind { case .resume, .train: AppColor.strength; case .recover: AppColor.recovery; case .fuel: AppColor.nutrition; case .weigh: AppColor.bodyweight; case .sleep: AppColor.sleep; case .objectives: AppColor.positive; case .evaluate: AppColor.elo }
    }
    private var symbol: String {
        switch next.kind { case .resume, .train: "dumbbell.fill"; case .recover: "figure.mind.and.body"; case .fuel: "flame.fill"; case .weigh: "scalemass"; case .sleep: "moon.fill"; case .objectives: "scope"; case .evaluate: "chart.bar.fill" }
    }
    var body: some View {
        Button(action: act) {
            PremiumCard(role: .action, tint: tint) {
                HStack(spacing: 14) {
                    Image(systemName: symbol).font(.title2).foregroundStyle(tint).frame(width: 48, height: 52)
                        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NEXT · \(next.title)").font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(tint)
                        Text(next.action).font(.headline).foregroundStyle(AppColor.text)
                        Text(next.detail).font(.caption).foregroundStyle(AppColor.muted).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right").foregroundStyle(tint).font(.caption.weight(.semibold))
                }
            }
        }.buttonStyle(PremiumPressStyle()).accessibilityIdentifier("dashboard.next.action").accessibilityValue(String(describing: next.kind))
    }
    private func act() {
        AppHaptics.tap(enabled: store.settings.hapticsEnabled)
        switch next.kind {
        case .resume: store.startLiveWorkout()
        case .train: if let routine = store.nextTrainingRoutine { _ = store.startRoutine(routine) } else { store.startLiveWorkout() }
        case .recover: store.navigationRequest = .recovery
        case .fuel: store.presentedSheet = .nutrition
        case .weigh: store.presentedSheet = .weight
        case .sleep: store.presentedSheet = .sleep
        case .objectives: store.presentedSheet = .objectives
        case .evaluate: showDaily()
        }
    }
}
