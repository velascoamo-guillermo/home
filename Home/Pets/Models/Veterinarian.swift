import Foundation

nonisolated struct Veterinarian: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var clinicName: String
    var phone: String
    var address: String
    var schedule: String
    var notes: String
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, phone, address, schedule, notes
        case clinicName = "clinic_name"
        case updatedAt  = "updated_at"
        case deletedAt  = "deleted_at"
    }

}

nonisolated extension Veterinarian: SyncableEntity {
    static let tableName = "veterinarian"
}
