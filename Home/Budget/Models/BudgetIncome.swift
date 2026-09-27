import Foundation

nonisolated struct BudgetIncome: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var memberId: UUID
    var month: String
    var amountCents: Int
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, month
        case memberId = "member_id"
        case amountCents = "amount_cents"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(memberId, forKey: .memberId)
        try c.encode(month, forKey: .month)
        try c.encode(amountCents, forKey: .amountCents)
        try c.encode(updatedAt, forKey: .updatedAt)
        // Explicit null so re-creating a tombstoned deterministic-ID row clears it remotely.
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

nonisolated extension BudgetIncome: SyncableEntity {
    static let tableName = "budget_incomes"
}
