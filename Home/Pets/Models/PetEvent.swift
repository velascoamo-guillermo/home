import Foundation

enum EventCategory: String, Codable, CaseIterable {
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

struct PetEvent: Codable, Identifiable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var category: EventCategory
    var notes: String
    var value: String?
    var fileIds: [UUID]
}
