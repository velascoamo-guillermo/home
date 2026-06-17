import Foundation

nonisolated struct TaskSection: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

}

nonisolated extension TaskSection: SyncableEntity {
    static let tableName = "task_sections"
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
