import SwiftUI

struct RecoveryView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "RECOVER TO RISE", title: "Body intelligence")
                PremiumCard(role: .inline) { VStack(alignment: .leading, spacing: 10) {
                    Text(store.ownerSystem.sickActive ? "Recovery comes first" : SemanticStatus.recovery(store.readiness.percent).title).font(.headline)
                    Text(store.brainDecision.reasons.last ?? "Log your training to understand recovery.").font(.subheadline).foregroundStyle(AppColor.secondary)
                    ContextualCoachButton(title: "Why am I still recovering?", question: "Why am I still recovering?")
                } }
                BodyMapView(report: store.readiness)
                PremiumCard(role: .inline) {
                    HStack(spacing: 16) {
                        ReadinessGauge(percent: store.readiness.percent, size: 60)
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "BODY READINESS")
                            Text(SemanticStatus.recovery(store.readiness.percent).title).font(.title3.weight(.semibold)).foregroundStyle(SemanticStatus.recovery(store.readiness.percent).tint)
                            Text("Estimate from your recorded activity").font(.caption).foregroundStyle(AppColor.muted)
                        }
                    }
                }
                HStack {
                    SectionHeader(title: "Muscle detail")
                    Button("Log sleep") { store.presentedSheet = .sleep }.font(.caption).frame(minHeight: 44)
                }
                Text("Estimates from logged training, sleep and fuel.").font(.caption).foregroundStyle(AppColor.muted)
                ForEach(BodyRegion.allCases) { region in
                    PremiumCard(role: .inline) {
                        DisclosureGroup {
                            VStack(spacing: 14) {
                                ForEach(store.readiness.muscles.filter { $0.muscle.group == region.rawValue }) { muscle in
                                    RecoveryStatusRow(name: muscle.muscle.title, percent: muscle.lastTrainedAt == nil ? nil : muscle.recoveryPercent)
                                }
                            }.padding(.top, 14)
                        } label: {
                            VStack(spacing: 10) {
                                HStack {
                                    Text(region.rawValue).font(.headline)
                                    Spacer()
                                    Text(region.recovery(in: store.readiness).map { "\(Int($0.rounded()))%" } ?? "Unknown")
                                        .foregroundStyle(region.tint(in: store.readiness)).font(.subheadline).monospacedDigit()
                                }
                                LinearProgress(progress: (region.recovery(in: store.readiness) ?? 0) / 100, tint: region.tint(in: store.readiness), height: 4)
                                Text(region.recovery(in: store.readiness).map { $0 >= 85 ? "Ready for comfortable training" : "Still recovering · avoid heavy work here" } ?? "Log activity to learn this muscle's recovery").font(.caption).foregroundStyle(AppColor.secondary)
                            }
                        }
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.task { if !AppMotion.snapshotMode { await AnatomyAssetCache.shared.preload() } }.accessibilityIdentifier("screen.recovery").featureBackground(tint: AppColor.recovery)
    }
}
