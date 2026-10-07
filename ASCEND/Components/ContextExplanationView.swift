import SwiftUI

struct ContextExplanationView: View {
    @Environment(AppStore.self) private var store
    let focus: String
    let facts: [String]
    let confidence: Confidence
    @State private var explanation: BrainInsight?
    private var fingerprint: String { "\(store.settings.onDeviceAIEnabled):\(confidence.rawValue):\(focus):" + facts.joined(separator: "|") }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: focus.uppercased())
                Spacer()
                PillStatus(title: explanation?.source == .onDevice ? "ON DEVICE AI" : "LOCAL RULES", tint: AppColor.muted)
            }
            Text(explanation?.summary ?? facts.prefix(2).joined(separator: " ")).font(.caption).foregroundStyle(AppColor.muted)
        }.task(id: fingerprint) {
            let result = await store.explain(facts: facts, focus: focus, confidence: confidence)
            if !Task.isCancelled { explanation = result }
        }
    }
}
