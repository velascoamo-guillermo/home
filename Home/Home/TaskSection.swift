import Foundation

struct TaskSection: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var icon: String

    enum CodingKeys: String, CodingKey {
        case id, name, icon
    }
}

// MARK: - Predefined

extension TaskSection {
    enum Predefined: String, CaseIterable {
        case general    = "wrench"
        case plumbing   = "drop"
        case kitchen    = "flame"
        case climate    = "fan"
        case lighting   = "lightbulb"
        case cleaning   = "trash"
        case storage    = "shippingbox"
        case repairs    = "hammer"
        case garden     = "leaf"
        case airQuality = "air.purifier"

        var icon: String { rawValue }

        var name: String {
            switch self {
            case .general:    return "General"
            case .plumbing:   return "Plumbing"
            case .kitchen:    return "Kitchen"
            case .climate:    return "Climate"
            case .lighting:   return "Lighting"
            case .cleaning:   return "Cleaning"
            case .storage:    return "Storage"
            case .repairs:    return "Repairs"
            case .garden:     return "Garden"
            case .airQuality: return "Air Quality"
            }
        }
    }
}
