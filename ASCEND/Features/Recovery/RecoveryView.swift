import SwiftUI

struct RecoveryView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "RECOVER TO RISE", title: "Body intelligence")
                PremiumCard(accented: true) {
                    HStack(spacing: 22) {
                        ReadinessGauge(percent: store.readiness.percent, size: 88)
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "BODY READINESS")
                            Text(store.readiness.state?.rawValue.capitalized ?? "Learning").font(.title2.weight(.semibold))
                            PillStatus(title: "\(store.readiness.confidence.rawValue.uppercased()) CONFIDENCE", tint: AppColor.muted)
                        }
                    }
                }
                BodyMapView(report: store.readiness)
                HStack {
                    SectionHeader(title: "Muscle detail")
                    Button("Log sleep") { store.presentedSheet = .sleep }.font(.caption).frame(minHeight: 44)
                }
                Text("Training + sleep + fuel · recovery estimates").font(.caption).foregroundStyle(AppColor.muted)
                ForEach(BodyRegion.allCases) { region in
                    PremiumCard {
                        DisclosureGroup {
                            VStack(spacing: 14) {
                                ForEach(store.readiness.muscles.filter { $0.muscle.group == region.rawValue }) { muscle in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(muscle.muscle.title).font(.caption)
                                            Spacer()
                                            Text(muscle.lastTrainedAt == nil ? "Unlogged" : "\(Int(muscle.recoveryPercent))%")
                                                .font(.caption).foregroundStyle(AppColor.muted).monospacedDigit()
                                        }
                                        LinearProgress(progress: muscle.lastTrainedAt == nil ? 0 : muscle.recoveryPercent / 100,
                                            tint: region.tint(in: store.readiness))
                                    }
                                }
                            }.padding(.top, 14)
                        } label: {
                            VStack(spacing: 10) {
                                HStack {
                                    Text(region.rawValue).font(.headline)
                                    Spacer()
                                    Text(region.recovery(in: store.readiness).map { "\(Int($0))%" } ?? "—")
                                        .foregroundStyle(region.tint(in: store.readiness)).font(.subheadline).monospacedDigit()
                                }
                                LinearProgress(progress: (region.recovery(in: store.readiness) ?? 0) / 100, tint: region.tint(in: store.readiness), height: 4)
                            }
                        }
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.recovery").featureBackground()
    }
}
