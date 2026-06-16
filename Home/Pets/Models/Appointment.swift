import Foundation

enum AppointmentStatus: String, Codable, CaseIterable, Hashable {
    case upcoming, done, cancelled
}

struct Appointment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var reason: String
    var notes: String
    var status: AppointmentStatus
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, date, reason, notes, status
        case petId     = "pet_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

extension Appointment: SyncableEntity {
    static let tableName = "appointments"
}
