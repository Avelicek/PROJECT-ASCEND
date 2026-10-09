import SwiftUI

struct RecoveryView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "RECOVER TO RISE", title: "Body intelligence")
                PremiumCard(role: .inline) { VStack(alignment: .leading, spacing: 10) { Eyebrow(text: "SO WHAT?"); Text(store.brainDecision.reasons.joined(separator: " ")).font(.subheadline).foregroundStyle(AppColor.secondary) } }
                BodyMapView(report: store.readiness)
                PremiumCard(role: .inline) {
                    HStack(spacing: 16) {
                        ReadinessGauge(percent: store.readiness.percent, size: 60)
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "BODY READINESS")
                            Text(SemanticStatus.recovery(store.readiness.percent).title).font(.title3.weight(.semibold)).foregroundStyle(SemanticStatus.recovery(store.readiness.percent).tint)
                            StatusPill(status: .confidence(store.readiness.confidence), title: "\(store.readiness.confidence.rawValue.uppercased()) CONFIDENCE")
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
                            }
                        }
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.task { if !AppMotion.snapshotMode { await AnatomyAssetCache.shared.preload() } }.accessibilityIdentifier("screen.recovery").featureBackground(tint: AppColor.recovery)
    }
}
