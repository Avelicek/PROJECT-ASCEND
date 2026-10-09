import SwiftUI

struct TodayCoachHero: View {
    @Environment(AppStore.self) private var store
    let showScore: () -> Void
    var body: some View {
        PremiumCard(role: .hero) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(text: "TODAY"); Spacer(); Text("IN PROGRESS").font(.caption2).foregroundStyle(AppColor.muted) }
                Button(action: showScore) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        CountUpText(value: Double(store.projectedScore.delta), signed: true).font(.system(.largeTitle, design: .rounded, weight: .semibold)).foregroundStyle(AppColor.text)
                        Text("ELO").font(.title3).foregroundStyle(AppColor.muted)
                        Spacer(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(AppColor.muted)
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityIdentifier("dashboard.daily.elo")
                Text(DailyELOEngine().description(store.projectedScore.delta)).font(.headline).foregroundStyle(AppColor.secondary)
                let done = store.todayObjectives.filter { $0.completedAt != nil }.count
                Text("\(done) / \(store.todayObjectives.count) objectives").font(.caption).foregroundStyle(AppColor.muted)
                LinearProgress(progress: Double(done) / Double(max(1, store.todayObjectives.count)), tint: AppColor.positive)
                if let previous = store.history.last {
                    Text("\(previous.dayKey) · \(previous.delta.formatted(.number.sign(strategy: .always()))) ELO finalized")
                        .font(.caption).foregroundStyle(AppColor.muted).accessibilityIdentifier("dashboard.previous.elo").accessibilityValue(String(previous.elo))
                }
            }
        }
    }
}

struct NextCoachActionCard: View {
    @Environment(AppStore.self) private var store
    let details: () -> Void
    var body: some View {
        let action = store.nextBestAction
        PremiumCard(role: .action, tint: AppColor.accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { CoachIdentity(); Eyebrow(text: "NEXT BEST ACTION"); Spacer(); Button(action: details) { Image(systemName: "info.circle").frame(width: 44, height: 44) }.accessibilityLabel("Why this recommendation?").accessibilityIdentifier("brain.detail") }
                Text(action.title).accessibilityIdentifier("brain.hero").font(.title2.weight(.semibold)).foregroundStyle(AppColor.text).fixedSize(horizontal: false, vertical: true)
                Text(action.reason).font(.subheadline).foregroundStyle(AppColor.secondary).fixedSize(horizontal: false, vertical: true)
                PrimaryAction(title: action.button, symbol: "arrow.right") { store.openCoachAction(action.action) }.accessibilityIdentifier("coach.next.action")
                ContextualCoachButton(title: "Ask about this plan", question: "Why this workout?")
            }
        }
    }
}

struct GoalProjectionCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let projection = store.goalProjection
        PremiumCard(role: .metric, tint: AppColor.bodyweight) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Eyebrow(text: "YOUR GOAL").accessibilityIdentifier("coach.goal.projection"); Spacer(); if let target = projection.target { Text("\(target.formatted()) kg").font(.headline) } }
                if projection.target == nil { Text("Set a weight goal in Profile.").font(.subheadline).foregroundStyle(AppColor.secondary) }
                else {
                    LinearProgress(progress: store.progress.goalProgress ?? 0, tint: AppColor.bodyweight)
                    if let current = projection.current, let target = projection.target {
                        Text("\(current.formatted(.number.precision(.fractionLength(1)))) → \(target.formatted(.number.precision(.fractionLength(1)))) kg").font(.subheadline).foregroundStyle(AppColor.secondary)
                    }
                    if let weeks = projection.estimatedWeeks, let date = projection.estimatedDate {
                        Text("Estimated \(weeks) weeks").font(.title2.weight(.semibold)).contentTransition(.numericText()).accessibilityIdentifier("goal.eta")
                        Text("Around \(date.formatted(.dateTime.month(.wide).day()))").font(.subheadline).foregroundStyle(AppColor.secondary)
                    } else if projection.withinGoalRange {
                        Text("Within your goal range").font(.headline)
                    } else {
                        Text(projection.weeklyChange == nil ? "Learning your trend" : "Let's review your pace").font(.headline)
                        Text(projection.explanation).font(.caption).foregroundStyle(AppColor.secondary)
                    }
                    if let pace = projection.weeklyChange {
                        Text("\(pace >= 0 ? "Gaining" : "Losing") about \(abs(pace).formatted(.number.precision(.fractionLength(2)))) kg/week.").font(.caption).foregroundStyle(AppColor.secondary)
                    }
                    Button("Talk to ASCEND", systemImage: "bubble.left") { store.presentedSheet = .goalCoach }.font(.subheadline).frame(minHeight: 44).accessibilityIdentifier("goal.coach")
                    DisclosureGroup("Why this estimate?") {
                        Text(projection.explanation).font(.caption).foregroundStyle(AppColor.secondary).padding(.top, 8)
                        Text("\(projection.confidence.rawValue.capitalized) confidence · weight trend only. Fuel and training inform coaching, not this date.").font(.caption).foregroundStyle(AppColor.muted)
                    }.font(.caption)
                }
            }
        }.animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.interaction, value: projection.estimatedWeeks)
    }
}

struct MorningCheckInView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var weight = 0.0
    @State private var hours = 0.0
    @State private var includeWeight = true
    @State private var includeSleep = true
    @State private var feeling = 3
    @State private var soreness = 0
    @State private var submitted = false
    @State private var previousReadiness: Double?
    var body: some View {
        Form {
            if submitted {
                Section("READINESS UPDATED") {
                    Text("\(previousReadiness.map { String(Int($0.rounded())) } ?? "Learning") → \(store.readiness.percent.map { String(Int($0.rounded())) } ?? "Learning")").font(.largeTitle.weight(.semibold)).contentTransition(.numericText())
                    Text("Today's plan has been reviewed using your check-in.")
                    Text(store.brainDecision.reasons.joined(separator: " ")).font(.subheadline)
                    Button("View today's plan") { store.navigationRequest = .workout; dismiss() }
                }
            } else {
                Section("Morning weight") {
                    Toggle("Record weight", isOn: $includeWeight)
                    if includeWeight { NumericField(title: "Weight · kg", value: $weight).font(.title2) }
                }
                Section("Last night's sleep") {
                    Toggle("Record sleep", isOn: $includeSleep)
                    if includeSleep { NumericField(title: "Sleep · hours", value: $hours).font(.title2) }
                }
                Section("How do you feel?") {
                    Picker("Feeling", selection: $feeling) { Text("Very low").tag(1); Text("Low").tag(2); Text("Okay").tag(3); Text("Good").tag(4); Text("Great").tag(5) }
                    Stepper("Soreness · \(soreness) / 5", value: $soreness, in: 0...5)
                    Text("Skip unknown measurements. Soreness and feeling guide session difficulty, not a medical recovery percentage.").font(.caption).foregroundStyle(AppColor.muted)
                }
                Section { PrimaryAction(title: "Update my plan", symbol: "arrow.up.right") {
                    previousReadiness = store.readiness.percent
                    if store.morningCheckIn(weight: includeWeight ? weight : nil, hours: includeSleep ? hours : nil, feeling: feeling, soreness: soreness) { withAnimation(AppMotion.snapshotMode ? nil : AppAnimation.interaction) { submitted = true }; AppHaptics.success(enabled: store.settings.hapticsEnabled) }
                }.accessibilityIdentifier("checkin.submit") }
            }
        }.navigationTitle("Morning check-in").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.checkin")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { weight = store.progress.actualWeight ?? 0; hours = store.todaySleep?.durationHours ?? 0; feeling = store.checkInToday?.feeling ?? 3; soreness = store.checkInToday?.soreness ?? 0 }
    }
}

struct AskAscendView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var answer: CoachAnswer?
    @State private var interpretation: BrainInsight?
    @State private var answering = false
    @State private var requestID = UUID()
    private let suggestions = ["Should I train today?", "Why did you remove chest?", "Should I increase my bench?", "Why did I lose ELO?", "What should I eat today?", "Can I reach my goal by December?"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { CoachIdentity(); Text("Ask ASCEND").font(.title2.weight(.semibold)) }
                Text("Your training, explained.").font(.subheadline).foregroundStyle(AppColor.secondary)
                TextField("Ask about your recorded progress", text: $question, axis: .vertical).lineLimit(2...4).padding(16).background(AppColor.surface, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("coach.question")
                PrimaryAction(title: answering ? "Reading your context…" : "Ask", symbol: "arrow.up") { ask() }.disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answering).accessibilityIdentifier("coach.ask")
                if let answer {
                    factSection("OBSERVED", answer.observed)
                    factSection("ESTIMATES · \(answer.confidence.rawValue.uppercased()) CONFIDENCE", answer.estimates)
                    factSection("RECOMMENDATION", [answer.recommendation])
                    if let interpretation, interpretation.source == .onDevice { factSection("ON-DEVICE INTERPRETATION", [interpretation.summary]) }
                } else {
                    ForEach(suggestions, id: \.self) { suggestion in Button(suggestion) { question = suggestion; ask() }.font(.subheadline).foregroundStyle(AppColor.text).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading) }
                }
            }.padding(20)
        }.background(AppColor.background).navigationTitle("Coach").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.askascend")
            .onAppear { if let contextQuestion = store.coachQuestion { question = contextQuestion; store.coachQuestion = nil; ask() } }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    private func factSection(_ title: String, _ facts: [String]) -> some View {
        Group { if !facts.isEmpty { PremiumCard { VStack(alignment: .leading, spacing: 10) { Eyebrow(text: title); ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in Text(fact).font(.subheadline).foregroundStyle(AppColor.secondary).fixedSize(horizontal: false, vertical: true) } } } } }
    }
    private func ask() {
        let context = store.coachContext(for: question)
        let result = CoachReasoningEngine().answer(String(question.prefix(1000)), context: context)
        answer = result; interpretation = nil
        guard store.settings.onDeviceAIEnabled else { return }
        answering = true; let id = UUID(); requestID = id
        Task {
            let insight = await store.explain(facts: result.observed + result.estimates + [result.recommendation], focus: "Answer the user's data-grounded question: " + String(question.prefix(200)), confidence: result.confidence)
            guard id == requestID else { return }; interpretation = insight; answering = false
        }
    }
}
