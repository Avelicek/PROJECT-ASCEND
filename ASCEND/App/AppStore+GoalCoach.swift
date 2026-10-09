import Foundation

extension AppStore {
    private var goalRecentFuel: [NutritionEntry] { nutrition.filter { $0.date >= policy.adding(days: -13, to: policy.start(of: now)) && $0.date <= now } }
    var goalFuelDays: Int { Set(goalRecentFuel.map(\.dayKey)).count }
    var goalFuelCoverage: Double {
        FitnessMath.average(goalRecentFuel.map { min(1, $0.calories / max(1, $0.calorieGoal)) }) ?? 0
    }
    var goalTrainingSessions: Int { sessions.filter { !$0.isQuickLog && $0.hasWorkingSets && $0.evaluationDate >= policy.adding(days: -13, to: policy.start(of: now)) && $0.evaluationDate <= now }.count }
    func goalNegotiation(deadline: Date?, faster: Bool) -> GoalNegotiation {
        let reviewing = ownerSystem.goalPlanReviewAt.map { $0 > now } ?? false
        let underage = ownerSystem.birthDate.map { (policy.calendar.dateComponents([.year], from: $0, to: now).year ?? 0) < 18 } ?? false
        return GoalCoachEngine().negotiate(projection: goalProjection, deadline: deadline, faster: faster,
            calories: profile.calorieGoal, fuelCoverage: goalFuelDays >= 7 ? goalFuelCoverage : 0,
            protected: ownerSystem.sickActive || ownerSystem.sleepStartedAt != nil || reviewing || underage,
            now: now, policy: policy)
    }
    @discardableResult func applyGoalNegotiation(deadline: Date?, faster: Bool) -> Bool {
        let proposal = goalNegotiation(deadline: deadline, faster: faster)
        guard proposal.canAdjust, let pace = proposal.proposedPace else { errorMessage = "The plan needs more observations before adjusting."; return false }
        var draft = ProfileDraft(store: self)
        draft.currentWeight = nil // Changing a plan never creates a weigh-in.
        draft.weeklyChange = pace; draft.deadline = proposal.proposedDate
        draft.calories += proposal.calorieAdjustment
        let previous = ownerSystem
        var staged = previous; staged.goalPlanReviewAt = policy.adding(days: 14, to: now)
        do { try staged.validate(); try ownerStorage?.write(staged) }
        catch { errorMessage = error.localizedDescription; return false }
        guard saveProfile(draft) else { try? ownerStorage?.write(previous); return false }
        ownerSystem = staged; refreshSafely()
        return true
    }
}
