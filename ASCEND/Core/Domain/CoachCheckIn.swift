import Foundation

public struct MorningCheckIn: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var date: Date
    public var feeling: Int
    public var soreness: Int
    public init(date: Date, feeling: Int, soreness: Int) { self.date = date; self.feeling = feeling; self.soreness = soreness }
    public var isValid: Bool { OwnerDates.valid(date) && (1...5).contains(feeling) && (0...5).contains(soreness) }
}
public enum CoachNotificationCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case morning, workout, rest, nutrition, recovery, objectives, weekly, goal, intervention
    public var id: String { rawValue }
    public var title: String { switch self { case .morning: "Morning check-in"; case .workout: "Workout reminder"; case .rest: "Rest complete"; case .nutrition: "Nutrition target"; case .recovery: "Recovery guidance"; case .objectives: "Daily objectives"; case .weekly: "Weekly coach report"; case .goal: "Goal progress"; case .intervention: "Important plan adjustments" } }
}
public struct CoachPreferences: Codable, Sendable {
    public var hour = 8
    public var minute = 0
    public var enabled: Set<CoachNotificationCategory> = [.morning, .rest, .weekly]
    public init() {}
    public var isValid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }
}
