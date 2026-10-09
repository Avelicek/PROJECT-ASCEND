import SwiftUI

struct ContextualCoachButton: View {
    @Environment(AppStore.self) private var store
    @State private var presenting = false
    let title: String
    let question: String
    var body: some View {
        Button(title, systemImage: "bubble.left") { store.coachQuestion = question; presenting = true }
            .font(.subheadline).frame(minHeight: 44).accessibilityIdentifier("coach.context.\(question)")
            .sheet(isPresented: $presenting) { NavigationStack { AskAscendView().environment(store) }.preferredColorScheme(.dark) }
    }
}

struct GoalCoachView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var faster = false
    @State private var useDeadline = false
    @State private var deadline = Date.now
    @State private var editingGoal = false
    @State private var confirm = false
    @State private var applied = false
    private var result: GoalNegotiation {
        store.goalNegotiation(deadline: useDeadline ? deadline : nil, faster: faster)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { CoachIdentity(); Text("Let's talk about your goal").font(.title2.weight(.semibold)) }
                if let weight = store.goalProjection.current, let target = store.profile.targetWeightKG {
                    Text("\(weight.formatted(.number.precision(.fractionLength(1)))) → \(target.formatted()) kg").font(.title3).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Button("I need it faster") { withAnimation(reduceMotion ? nil : AppAnimation.interaction) { faster = true; useDeadline = false; applied = false } }.frame(minHeight: 44).accessibilityIdentifier("goal.faster")
                    Button("I need it by \(deadline.formatted(.dateTime.month(.wide).day()))") { useDeadline = true; faster = false; applied = false }.frame(minHeight: 44).accessibilityIdentifier("goal.deadline")
                    if useDeadline { DatePicker("My deadline", selection: $deadline, in: store.policy.adding(days: 1, to: store.now)..., displayedComponents: .date).onChange(of: deadline) { _, _ in applied = false } }
                    Button("Is this realistic?") { faster = false; useDeadline = true; applied = false }.frame(minHeight: 44)
                    Button("Change my goal") { editingGoal = true }.frame(minHeight: 44).accessibilityIdentifier("goal.change")
                }.font(.subheadline)
                PremiumCard(role: .hero, tint: AppColor.bodyweight) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(applied ? "Plan updated" : result.headline).font(.headline)
                        Text(applied ? "Keep comparable weigh-ins. We'll review this small experiment after two weeks." : result.explanation).font(.subheadline).foregroundStyle(AppColor.secondary)
                        if let date = result.proposedDate, faster || useDeadline {
                            Text("Planning estimate · \(date.formatted(date: .abbreviated, time: .omitted))").font(.subheadline).contentTransition(.numericText())
                        }
                        if result.canAdjust && !applied {
                            Text(result.calorieAdjustment > 0 ? "Try \(Int(store.profile.calorieGoal + result.calorieAdjustment)) kcal/day (+100). No extra workouts." : "Update the pace and review date. Your fuel target stays the same.").font(.caption).foregroundStyle(AppColor.muted)
                            PrimaryAction(title: "Adjust my plan", symbol: "checkmark") { confirm = true }.accessibilityIdentifier("goal.adjust")
                        }
                        Button("Keep current pace") { dismiss() }.frame(minHeight: 44)
                    }
                }
                DisclosureGroup("What ASCEND knows") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.goalProjection.explanation)
                        Text("Fuel goal: \(Int(store.profile.calorieGoal)) kcal · coverage \(Int(store.goalFuelCoverage * 100))% over logged days.")
                        Text("\(store.goalFuelDays) of 14 days logged · \(store.goalTrainingSessions) workouts. \(store.brainDecision.session?.name ?? "Recovery plan").")
                        if let deadline = store.profile.targetDeadline { Text("Saved deadline: \(deadline.formatted(date: .abbreviated, time: .omitted))") }
                        Text(store.brainDecision.reasons.first ?? "Keep observations consistent.")
                    }.font(.caption).foregroundStyle(AppColor.secondary).padding(.top, 8)
                }
                ContextualCoachButton(title: "Ask a different question", question: "Is my bodyweight goal realistic?")
            }.padding(20)
        }.featureBackground(tint: AppColor.bodyweight).navigationTitle("Goal Coach").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.goalcoach")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { deadline = store.profile.targetDeadline ?? nextDecember() }
            .sheet(isPresented: $editingGoal) { NavigationStack { ProfileEditor(store: store).environment(store) }.preferredColorScheme(.dark) }
            .confirmationDialog("Apply this two-week plan experiment?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Apply reviewed plan") { applied = store.applyGoalNegotiation(deadline: useDeadline ? deadline : nil, faster: faster) }
            } message: { Text("Only your goal pace, planning date and the displayed fuel adjustment change. The estimate remains uncertain.") }
    }
    private func nextDecember() -> Date {
        let calendar = store.policy.calendar
        let year = calendar.component(.year, from: store.now)
        let first = calendar.date(from: .init(year: year, month: 12, day: 1)) ?? store.policy.adding(days: 60, to: store.now)
        return first > store.now ? first : calendar.date(byAdding: .year, value: 1, to: first) ?? first
    }
}
