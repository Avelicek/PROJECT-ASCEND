import Foundation
import SwiftData

enum AscendSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [UserProfile.self, UserSettings.self, BodyWeightEntry.self, NutritionEntry.self, SleepEntry.self,
         Exercise.self, WorkoutSession.self, WorkoutExercise.self, WorkoutSet.self, DailyObjective.self,
         DailyObjectiveCompletion.self, DailyEvaluation.self, ELOHistoryEntry.self, PersonalRecord.self,
         MuscleState.self, BrainInsightRecord.self]
    }
}
enum AscendMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AscendSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
enum PersistenceController {
    @MainActor static func makeContainer(inMemory: Bool, folder: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: AscendSchemaV1.self)
        if !inMemory && folder == nil { try OwnerStoreLocation.cleanRetiredData() }
        let selected = try folder ?? (inMemory ? nil : OwnerStoreLocation.selectedFolder())
        let configuration: ModelConfiguration
        if let selected, selected.lastPathComponent != "ASCEND" {
            configuration = ModelConfiguration("Ascend", schema: schema, url: selected.appendingPathComponent("Ascend.store"), cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration("Ascend", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: AscendMigrationPlan.self, configurations: [configuration])
    }
}
