import Foundation

nonisolated struct WeightEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var weightKg: Double
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, date
        case petId     = "pet_id"
        case weightKg  = "weight_kg"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated extension WeightEntry: SyncableEntity {
    static let tableName = "weight_entries"
}
