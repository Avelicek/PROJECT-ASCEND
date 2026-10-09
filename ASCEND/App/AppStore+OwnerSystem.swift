import Foundation

extension AppStore {
    @discardableResult func saveOwnerSystem(_ change: (inout OwnerSystem) throws -> Void) -> Bool {
        do { var state = ownerSystem; try change(&state); try state.validate(); try ownerStorage?.write(state); ownerSystem = state; refreshSafely(); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
    func startSleep() {
        guard ownerSystem.sleepStartedAt == nil else { return }
        if saveOwnerSystem({ $0.sleepStartedAt = actionDate(); $0.sleepEndedAt = nil }) {
            presentedSheet = nil; liveWorkoutPresented = false
        }
    }
    func endSleep() { guard ownerSystem.sleepStartedAt != nil else { return }; _ = saveOwnerSystem { $0.sleepEndedAt = actionDate() } }
    func cancelSleep() { _ = saveOwnerSystem { $0.sleepStartedAt = nil; $0.sleepEndedAt = nil } }
    @discardableResult func finishSleep(start: Date, end: Date, quality: Int, replace: Bool) -> Bool {
        do {
            guard ownerSystem.sleepStartedAt != nil else { throw InputError.invalid("No sleep interval is active.") }
            let hours = try RecordedSleep.hours(start: start, end: end, now: actionDate())
            guard replace || !sleep.contains(where: { $0.dayKey == policy.key(for: end) }) else { throw InputError.invalid("Confirm replacement of the existing sleep log for this wake day.") }
            // Commit the recorded interval before unlocking. A failed owner-file write keeps
            // the lock and permits a reviewed retry; a process interruption never loses sleep.
            guard logSleep(hours: hours, quality: quality, on: end, bedtime: start, wakeTime: end) else { return false }
            guard saveOwnerSystem({ $0.sleepStartedAt = nil; $0.sleepEndedAt = nil }) else { return false }
            presentedSheet = .checkIn
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func startSick(note: String) { guard !ownerSystem.sickActive else { return }; _ = saveOwnerSystem { $0.sickIntervals.append(.init(start: actionDate(), note: String(note.prefix(400)))) } }
    func endSick() { guard ownerSystem.sickActive else { return }; _ = saveOwnerSystem { state in state.sickIntervals[state.sickIntervals.count - 1].end = actionDate() } }
    @discardableResult func addMeasurement(_ entry: BodyMeasurement) -> Bool {
        guard entry.isValid, entry.date <= actionDate(), [entry.chest, entry.waist, entry.hips, entry.biceps, entry.thigh].contains(where: { $0 != nil }) else { errorMessage = "Enter at least one circumference between 5 and 300 cm."; return false }
        return saveOwnerSystem { $0.measurements.append(entry); $0.measurements.sort { $0.date < $1.date } }
    }
    @discardableResult func changeManualObjective(_ occurrence: DailyObjectiveCompletion, adding value: Double) -> Bool {
        perform {
            guard policy.sameDay(occurrence.date, now), [.count, .duration].contains(ObjectiveKind(rawValue: occurrence.kindRaw) ?? .custom), value.isFinite, value > 0, value <= 20000 else { throw InputError.invalid("Enter a positive count or duration.") }
            occurrence.value += value
        }
    }
    @discardableResult func reduceObjectiveToday(_ occurrence: DailyObjectiveCompletion) -> Bool {
        perform {
            guard policy.sameDay(occurrence.date, now), occurrence.completedAt == nil, !occurrence.recoveryExempt else { throw InputError.invalid("This objective cannot be reduced.") }
            occurrence.target = max(1, max(occurrence.value, (occurrence.target / 2).rounded(.up)))
        }
    }
}
