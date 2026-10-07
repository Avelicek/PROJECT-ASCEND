import SwiftUI
import Charts

private enum AnalyticsPage: String, CaseIterable, Identifiable {
    case elo = "ELO", volume = "Volume", strength = "Strength", consistency = "Consistency", records = "PRs"
    var id: String { rawValue }
}
private struct TrainingChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
}

struct TrainingAnalyticsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var page: AnalyticsPage = .elo
    @State private var exerciseID = "db_row"
    init(exercises: Bool = false) { _page = State(initialValue: exercises ? .strength : .elo) }
    private var candidates: [Exercise] { store.exercises.filter { $0.trackingMode == .weightAndReps && !$0.bodyweightCapable } }
    private var points: [TrainingChartPoint] {
        let recent = store.sessions.filter { $0.hasWorkingSets && !$0.isQuickLog && $0.evaluationDate <= store.now }.prefix(60)
        return recent.compactMap { session in
            let values: Double
            if page == .volume {
                values = session.exercises.filter { $0.trackingMode == .weightAndReps || $0.trackingMode == .reps }
                    .reduce(0) { $0 + WorkoutEngine().volume($1.sets.filter { !$0.isWarmup }.map(\.performance)) }
            } else {
                let sets = session.exercises.filter { $0.exercise?.catalogID == exerciseID }.flatMap(\.sets).filter { !$0.isWarmup }.map(\.performance)
                values = WorkoutEngine().recordCandidates(sets).first { $0.kind == .estimatedOneRepMax }?.value ?? 0
            }
            return values > 0 ? TrainingChartPoint(id: session.id, date: session.evaluationDate, value: values) : nil
        }.sorted { $0.date < $1.date }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AnalyticsPage.allCases) { item in
                            Button { page = item } label: { Text(item.rawValue).font(.caption.weight(.medium)).padding(12).background(page == item ? AppColor.elo.opacity(0.15) : AppColor.surface, in: Capsule()).foregroundStyle(page == item ? AppColor.elo : AppColor.muted) }
                        }
                    }
                }
                switch page {
                case .elo: eloChart
                case .volume, .strength: trainingChart
                case .consistency: calendar
                case .records: recordTimeline
                }
            }.padding(20)
        }.background(AppColor.background).navigationTitle("Your trends").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    private var eloChart: some View {
        PremiumCard(role: .analytics) {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: "FINALIZED ELO")
                CountUpText(value: Double(store.currentELO)).font(.largeTitle.weight(.semibold)).foregroundStyle(AppColor.eloGradient)
                if store.history.count < 2 { Text("Close two recorded days to reveal a rating trend.").font(.caption).foregroundStyle(AppColor.muted) }
                else {
                    Chart(store.history.suffix(60), id: \.dayKey) { entry in
                        LineMark(x: .value("Day", entry.date), y: .value("ELO", entry.elo)).foregroundStyle(AppColor.elo)
                        PointMark(x: .value("Day", entry.date), y: .value("ELO", entry.elo)).foregroundStyle(AppColor.elo).symbolSize(12)
                    }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 210).accessibilityLabel("Finalized daily ELO history")
                }
            }
        }
    }
    private var trainingChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            if page == .strength {
                Picker("Exercise", selection: $exerciseID) { ForEach(candidates, id: \.catalogID) { Text($0.name).tag($0.catalogID) } }.pickerStyle(.menu).tint(AppColor.strength)
            }
            PremiumCard(role: .analytics) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: page == .volume ? "EXTERNAL SESSION VOLUME · KG" : "ESTIMATED 1RM · KG")
                    if points.isEmpty { Text("Log comparable full working sets to reveal this trend.").font(.caption).foregroundStyle(AppColor.muted) }
                    else {
                        Chart(points) { point in
                            LineMark(x: .value("Date", point.date), y: .value("kg", point.value)).foregroundStyle(AppColor.strength)
                            PointMark(x: .value("Date", point.date), y: .value("kg", point.value)).foregroundStyle(AppColor.strength).symbolSize(22)
                        }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 210)
                        if let latest = points.last {
                            HStack { StatBlock(title: "Latest", value: latest.value.formatted(.number.precision(.fractionLength(0...1))), tint: AppColor.strength); StatBlock(title: "Best", value: (points.map(\.value).max() ?? latest.value).formatted(.number.precision(.fractionLength(0...1))), tint: AppColor.gold) }
                        }
                    }
                    Text(page == .volume ? "Warm-ups and quick aggregate logs excluded. Body mass is not added to volume." : "Full working sets · 1–12 reps · loaded movements only.").font(.caption2).foregroundStyle(AppColor.muted)
                }
            }
        }
    }
    private var calendar: some View {
        PremiumCard(role: .analytics) {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: "FUEL CONSISTENCY · 28 DAYS")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(0..<28, id: \.self) { offset in
                        let date = store.policy.adding(days: offset - 27, to: store.policy.start(of: store.now))
                        let food = store.nutrition.first { $0.dayKey == store.policy.key(for: date) }
                        let met = food.map { (0.9...1.1).contains($0.calories / max(1, $0.calorieGoal)) && $0.proteinGrams / max(1, $0.proteinGoal) >= 0.9 } ?? false
                        RoundedRectangle(cornerRadius: 7).fill(food == nil ? AppColor.elevated : met ? AppColor.positive.opacity(0.65) : AppColor.nutrition.opacity(0.25))
                            .frame(height: 30).overlay { Text("\(store.policy.calendar.component(.day, from: date))").font(.system(size: 9)).foregroundStyle(food == nil ? AppColor.muted : AppColor.text) }
                            .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)): \(food == nil ? "unlogged" : met ? "fuel goals met" : "logged, goals not both met")")
                    }
                }
                Text("Mint · both goals met    Amber · logged    Gray · unlogged").font(.caption2).foregroundStyle(AppColor.muted)
            }
        }
    }
    private var recordTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "PR TIMELINE")
            if store.records.isEmpty { EmptyStateCard(symbol: "trophy", title: "Establish your baseline.", detail: "Records follow comparable working sessions.") }
            ForEach(store.records.prefix(40), id: \.id) { record in
                HStack(spacing: 12) {
                    Circle().fill(AppColor.gold).frame(width: 6, height: 6)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.exercises.first { $0.catalogID == record.exerciseCatalogID }?.name ?? record.exerciseCatalogID).font(.subheadline).foregroundStyle(AppColor.secondary)
                        Text(RecordPresentation.title(record.kindRaw, bodyweight: store.exercises.first { $0.catalogID == record.exerciseCatalogID }?.bodyweightCapable ?? false)).font(.caption2).foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("\(record.value.formatted(.number.precision(.fractionLength(0...1)))) \(RecordPresentation.unit(record.kindRaw))").font(.headline).foregroundStyle(AppColor.gold)
                        Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(AppColor.muted)
                    }
                }.padding(.vertical, 10)
            }
        }
    }
}
