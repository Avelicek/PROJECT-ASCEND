import SwiftUI

struct RecordHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FeatureHeader(eyebrow: "EARNED, NOT INVENTED", title: "Personal records")
                if store.records.isEmpty { EmptyStateCard(symbol: "trophy", title: "Set your baseline.", detail: "A record requires an earlier comparable session.") }
                ForEach(store.records.prefix(100), id: \.id) { record in
                    PremiumCard(accented: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Image(systemName: "trophy.fill").foregroundStyle(AppColor.warning); Text(store.exercises.first { $0.catalogID == record.exerciseCatalogID }?.name ?? record.exerciseCatalogID).font(.headline) }
                            Text(title(record)).font(.caption).foregroundStyle(AppColor.muted)
                            Text("\(record.value.formatted(.number.precision(.fractionLength(0...1)))) \(record.kindRaw.hasPrefix("reps") ? "reps" : "kg")").font(.title2.weight(.semibold)).monospacedDigit()
                            Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(AppColor.muted)
                        }
                    }
                }
            }.padding(20)
        }.background(AppColor.background).navigationTitle("PR history").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    private func title(_ record: PersonalRecord) -> String {
        if record.kindRaw.hasPrefix("reps@"), let kg = Double(record.kindRaw.dropFirst(5)) { return kg > 0 ? "Most reps · \(kg.formatted()) kg external load" : "Most reps · bodyweight / no external load" }
        switch RecordKind(rawValue: record.kindRaw) {
        case .weight: return "Heaviest external load"
        case .reps: return "Most reps · legacy record"
        case .volume: return "Highest session volume"
        case .estimatedOneRepMax: return "Estimated 1RM · loaded movement"
        case nil: return "Personal record"
        }
    }
}
