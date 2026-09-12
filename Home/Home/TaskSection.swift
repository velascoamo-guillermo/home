import Foundation

nonisolated struct TaskSection: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated extension TaskSection: SyncableEntity {
    static let tableName = "task_sections"
}

// MARK: - Predefined

extension TaskSection {
    nonisolated enum Predefined: String, CaseIterable, Codable, Sendable {
        case general, plumbing, kitchen, climate, lighting
        case cleaning, storage, repairs, garden, airQuality

        // Pre-redesign payloads stored the SF Symbol name instead of a key.
        init(legacyIcon: String) {
            switch legacyIcon {
            case "drop":         self = .plumbing
            case "flame":        self = .kitchen
            case "fan":          self = .climate
            case "lightbulb":    self = .lighting
            case "trash":        self = .cleaning
            case "shippingbox":  self = .storage
            case "hammer":       self = .repairs
            case "leaf":         self = .garden
            case "air.purifier": self = .airQuality
            default:             self = .general
            }
        }

        var name: String {
            switch self {
            case .general:    "General"
            case .plumbing:   "Plumbing"
            case .kitchen:    "Kitchen"
            case .climate:    "Climate"
            case .lighting:   "Lighting"
            case .cleaning:   "Cleaning"
            case .storage:    "Storage"
            case .repairs:    "Repairs"
            case .garden:     "Garden"
            case .airQuality: "Air Quality"
            }
        }
    }
}
