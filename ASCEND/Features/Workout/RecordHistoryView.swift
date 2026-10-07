import SwiftUI

enum PersonalBestFilter: String, CaseIterable, Hashable { case all = "All", strength = "Strength", reps = "Reps", bodyweight = "Bodyweight", volume = "Volume" }
enum RecordPresentation {
    static func kind(_ raw: String) -> RecordKind? { RecordKind(rawValue: String(raw.split(separator: "@").first ?? "")) }
    static func unit(_ raw: String) -> String {
        let kind = kind(raw)
        return kind == .reps || kind == .totalReps ? "reps" : kind == .addedWeightPerformance ? "kg·reps" : "kg"
    }
    static func title(_ raw: String, bodyweight: Bool) -> String {
        let context = Double(raw.split(separator: "@").last.map(String.init) ?? "") ?? 0
        switch kind(raw) {
        case .weight: return bodyweight ? "Most added weight" : "Heaviest external load"
        case .reps: return "Most reps · " + (context > 0 ? "\(bodyweight ? "+" : "")\(context.formatted()) kg" : "no added load")
        case .totalReps: return "Total working reps · " + (context > 0 ? "+\(context.formatted()) kg" : "bodyweight")
        case .volume: return "Highest external session volume"
        case .estimatedOneRepMax: return "Estimated 1RM · loaded movement"
        case .addedWeightPerformance: return "Added load × reps · external load only"
        case nil: return "Personal best"
        }
    }
}

struct RecordHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var filter = PersonalBestFilter.all
    @State private var detail: ExerciseRoute?
    private var records: [PersonalRecord] {
        store.records.filter { record in
            switch filter {
            case .all: return true
            case .strength:
                guard let kind = RecordPresentation.kind(record.kindRaw) else { return false }
                return [RecordKind.weight, .estimatedOneRepMax, .addedWeightPerformance].contains(kind)
            case .reps: return record.kindRaw.hasPrefix("reps") || record.kindRaw.hasPrefix("totalReps")
            case .bodyweight: return store.exercises.first { $0.catalogID == record.exerciseCatalogID }?.bodyweightCapable == true
            case .volume: return record.kindRaw == RecordKind.volume.rawValue
            }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FeatureHeader(eyebrow: "EARNED, NOT INVENTED", title: "Personal records")
                ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(PersonalBestFilter.allCases, id: \.self) { value in Button { filter = value } label: { Text(value.rawValue).font(.caption).padding(12).background(filter == value ? AppColor.gold.opacity(0.15) : AppColor.surface, in: Capsule()).foregroundStyle(filter == value ? AppColor.gold : AppColor.muted) } } } }
                if records.isEmpty { EmptyStateCard(symbol: "trophy", title: "Set your baseline.", detail: "A record requires an earlier comparable session.") }
                ForEach(records.prefix(100), id: \.id) { record in
                    Button { detail = .init(id: record.exerciseCatalogID) } label: { PremiumCard(role: .status, tint: AppColor.gold) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Image(systemName: "trophy.fill").foregroundStyle(AppColor.gold); Text(store.exercises.first { $0.catalogID == record.exerciseCatalogID }?.name ?? record.exerciseCatalogID).font(.headline).foregroundStyle(AppColor.text) }
                            Text(title(record)).font(.caption).foregroundStyle(AppColor.muted)
                            Text("\(record.value.formatted(.number.precision(.fractionLength(0...1)))) \(RecordPresentation.unit(record.kindRaw))").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(AppColor.goldGradient)
                            Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(AppColor.muted)
                        }
                    } }.buttonStyle(PremiumPressStyle())
                }
            }.padding(20)
        }.background(AppColor.background).navigationTitle("PR history").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $detail) { route in NavigationStack { ExerciseHistoryView(exerciseID: route.id).environment(store) }.preferredColorScheme(.dark) }
    }
    private func title(_ record: PersonalRecord) -> String {
        RecordPresentation.title(record.kindRaw, bodyweight: store.exercises.first { $0.catalogID == record.exerciseCatalogID }?.bodyweightCapable ?? false)
    }
}
