import Foundation
import SwiftData

@Model final class UserProfile {
    @Attribute(.unique) var key: String = "owner"
    var displayName: String
    var createdAt: Date
    var startingWeightKG: Double?
    var targetWeightKG: Double?
    var targetDeadline: Date?
    var desiredWeeklyChangeKG: Double
    var calorieGoal: Double
    var proteinGoal: Double
    var sleepTargetHours: Double
    var lifetimeCredits: Int
    init(displayName: String = "Athlete", createdAt: Date = .now) {
        self.displayName = displayName; self.createdAt = createdAt
        self.desiredWeeklyChangeKG = 0.25; self.calorieGoal = 3000; self.proteinGoal = 130
        self.sleepTargetHours = 8; self.lifetimeCredits = 0
    }
}

@Model final class UserSettings {
    @Attribute(.unique) var key: String = "settings"
    var timeZoneIdentifier: String
    var onDeviceAIEnabled: Bool
    var hapticsEnabled: Bool
    var automaticRestTimer: Bool
    var restTimerSeconds: Int
    var appearance: String
    init(timeZoneIdentifier: String = TimeZone.current.identifier) {
        self.timeZoneIdentifier = timeZoneIdentifier; self.onDeviceAIEnabled = false
        self.hapticsEnabled = true; self.automaticRestTimer = true; self.restTimerSeconds = 90
        self.appearance = "midnight"
    }
}

@Model final class BodyWeightEntry {
    @Attribute(.unique) var id: UUID
    var measuredAt: Date
    var kilograms: Double
    init(measuredAt: Date, kilograms: Double) { self.id = UUID(); self.measuredAt = measuredAt; self.kilograms = kilograms }
}

@Model final class NutritionEntry {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var calories: Double
    var proteinGrams: Double
    var calorieGoal: Double
    var proteinGoal: Double
    init(dayKey: String, date: Date, calories: Double, proteinGrams: Double, calorieGoal: Double, proteinGoal: Double) {
        self.dayKey = dayKey; self.date = date; self.calories = calories; self.proteinGrams = proteinGrams
        self.calorieGoal = calorieGoal; self.proteinGoal = proteinGoal
    }
}

@Model final class SleepEntry {
    @Attribute(.unique) var dayKey: String
    var date: Date // Assigned to the day of waking.
    var durationHours: Double
    var bedtime: Date?
    var wakeTime: Date?
    var quality: Int
    init(dayKey: String, date: Date, durationHours: Double, quality: Int, bedtime: Date? = nil, wakeTime: Date? = nil) {
        self.dayKey = dayKey; self.date = date; self.durationHours = durationHours; self.quality = quality
        self.bedtime = bedtime; self.wakeTime = wakeTime
    }
}
