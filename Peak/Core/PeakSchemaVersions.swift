import SwiftData

// MARK: - Versioned schema (required for reliable CloudKit + SwiftData)

enum PeakSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        PeakSchema.allModels
    }
}

enum PeakMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PeakSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}