import Foundation
import SwiftData

enum ExerciseCatalog {
    static let definitions = TrainingCatalog.definitions
    @MainActor static func seed(in context: ModelContext) throws {
        let existing = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.catalogID))
        for entry in definitions where !existing.contains(entry.id) {
            context.insert(Exercise(catalogID: entry.id, name: entry.name, category: entry.category, equipment: entry.equipment,
                                    trackingMode: entry.mode, bodyweightCapable: entry.bodyweight,
                                    additionalWeightAllowed: entry.additional, contributions: entry.muscles))
        }
    }
}
