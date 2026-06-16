import Foundation

enum EventCategory: String, Codable, CaseIterable, Hashable {
    case vaccine, grooming, medication, weight, other

    var icon: String {
        switch self {
        case .vaccine:    return "syringe"
        case .grooming:   return "scissors"
        case .medication: return "pill"
        case .weight:     return "scalemass"
        case .other:      return "note.text"
        }
    }
    var label: String { rawValue.capitalized }
}

struct PetEvent: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var category: EventCategory
    var notes: String
    var value: String?
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, date, title, category, notes, value
        case petId     = "pet_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

extension PetEvent: SyncableEntity {
    static let tableName = "pet_events"
}
