import Foundation

nonisolated struct BudgetCategory: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var estimateCents: Int = 0
    var sortOrder: Int = 0
    var archived: Bool = false
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, archived
        case estimateCents = "estimate_cents"
        case sortOrder = "sort_order"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(estimateCents, forKey: .estimateCents)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(archived, forKey: .archived)
        try c.encode(updatedAt, forKey: .updatedAt)
        // Explicit null so re-creating a tombstoned deterministic-ID row clears it remotely.
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

nonisolated extension BudgetCategory: SyncableEntity {
    static let tableName = "budget_categories"
}
