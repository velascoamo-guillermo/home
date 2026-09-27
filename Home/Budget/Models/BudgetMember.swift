import Foundation

nonisolated struct BudgetMember: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var sortOrder: Int = 0
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name
        case sortOrder = "sort_order"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(updatedAt, forKey: .updatedAt)
        // Explicit null: PostgREST upsert only writes keys present, so omitting it would
        // leave a remote tombstone in place when a deterministic-ID row is re-created.
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

nonisolated extension BudgetMember: SyncableEntity {
    static let tableName = "budget_members"
}
