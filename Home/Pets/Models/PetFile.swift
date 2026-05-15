import Foundation

enum FileSourceType: String, Codable {
    case photo, document, scan
}

enum FileLink: Codable, Equatable {
    case event(UUID)
    case clinicalEntry(UUID)
    case standalone

    private enum CodingKeys: String, CodingKey { case type, id }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "event":         self = .event(try c.decode(UUID.self, forKey: .id))
        case "clinicalEntry": self = .clinicalEntry(try c.decode(UUID.self, forKey: .id))
        default:              self = .standalone
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .event(let id):
            try c.encode("event", forKey: .type)
            try c.encode(id, forKey: .id)
        case .clinicalEntry(let id):
            try c.encode("clinicalEntry", forKey: .type)
            try c.encode(id, forKey: .id)
        case .standalone:
            try c.encode("standalone", forKey: .type)
        }
    }
}

struct PetFile: Codable, Identifiable {
    var id: UUID = UUID()
    var petId: UUID
    var filename: String
    var sourceType: FileSourceType
    var createdAt: Date
    var linkedTo: FileLink
}
