import Foundation

nonisolated struct ClinicalEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var description: String
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, date, title, description
        case petId     = "pet_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

}

nonisolated extension ClinicalEntry: SyncableEntity {
    static let tableName = "clinical_entries"
}
