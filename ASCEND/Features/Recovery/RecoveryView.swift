import SwiftUI

struct RecoveryView: View {
    @Environment(AppStore.self) private var store
    private var groups: [String] { Array(Set(Muscle.allCases.map(\.group))).sorted() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "RECOVER TO RISE", title: "Body intelligence")
                PremiumCard(accented: true) {
                    HStack(spacing: AppSpacing.lg) {
                        ZStack {
                            ProgressRing(progress: (store.readiness.percent ?? 0) / 100, tint: AppColor.blue)
                            Text(store.readiness.percent.map { "\(Int($0))%" } ?? "—").font(.title2.weight(.semibold)).monospacedDigit()
                        }.frame(width: 90, height: 90)
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "BODY READINESS")
                            Text(store.readiness.state?.rawValue.uppercased() ?? "LEARNING").font(.title3.weight(.semibold))
                            Text("\(store.readiness.confidence.rawValue.capitalized) confidence").font(.caption).foregroundStyle(AppColor.muted)
                        }
                    }
                }
                AnatomyPreview()
                HStack { SectionHeader(title: "Muscle recovery"); Button("Log sleep") { store.presentedSheet = .sleep }.font(.caption).frame(minHeight: 44) }
                Text("Baseline estimates combine training load, elapsed time, sleep and logged nutrition. Untrained muscles do not establish overall readiness.")
                    .font(.caption).foregroundStyle(AppColor.muted)
                ForEach(groups, id: \.self) { group in
                    PremiumCard {
                        DisclosureGroup {
                            VStack(spacing: AppSpacing.md) {
                                ForEach(store.readiness.muscles.filter { $0.muscle.group == group }) { muscle in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(muscle.muscle.title).font(.caption)
                                            Spacer()
                                            Text(muscle.lastTrainedAt == nil ? "No load logged" : "\(Int(muscle.recoveryPercent))%")
                                                .font(.caption).foregroundStyle(AppColor.muted).monospacedDigit()
                                        }
                                        LinearProgress(progress: muscle.recoveryPercent / 100,
                                            tint: muscle.recoveryPercent < 50 ? AppColor.warning : AppColor.blue)
                                    }
                                }
                            }.padding(.top, AppSpacing.md)
                        } label: {
                            HStack {
                                Text(group).font(.headline)
                                Spacer()
                                let trained = store.readiness.muscles.filter { $0.muscle.group == group && $0.lastTrainedAt != nil }
                                Text(trained.isEmpty ? "—" : "\(Int(trained.map(\.recoveryPercent).min() ?? 100))%")
                                    .foregroundStyle(AppColor.blue).font(.subheadline).monospacedDigit()
                            }
                        }
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.recovery").featureBackground()
    }
}
struct AnatomyPreview: View {
    var body: some View {
        PremiumCard {
            VStack(spacing: AppSpacing.md) {
                HStack { Eyebrow(text: "ANATOMY MODULE"); Spacer(); PillStatus(title: "BUILD 02", tint: AppColor.muted) }
                ZStack {
                    Circle().stroke(AppColor.blue.opacity(0.08), lineWidth: 1).frame(width: 174, height: 174)
                    Circle().stroke(AppColor.blue.opacity(0.05), lineWidth: 1).frame(width: 210, height: 210)
                    Image(systemName: "figure.stand").font(.system(size: 130, weight: .ultraLight)).foregroundStyle(AppColor.blue.opacity(0.55))
                }.frame(height: 220).accessibilityHidden(true)
                Text("Your body, in detail.").font(.headline)
                Text("Detailed muscle data is ready. The interactive anatomy artwork will arrive in the next build.")
                    .font(.caption).foregroundStyle(AppColor.muted).multilineTextAlignment(.center)
            }
        }
    }
}
