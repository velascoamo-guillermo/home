import Foundation

nonisolated struct BudgetExpense: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var amountCents: Int
    var categoryId: UUID
    var payerId: UUID
    var date: Date
    var recurringId: UUID? = nil
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, date
        case amountCents = "amount_cents"
        case categoryId = "category_id"
        case payerId = "payer_id"
        case recurringId = "recurring_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(amountCents, forKey: .amountCents)
        try c.encode(categoryId, forKey: .categoryId)
        try c.encode(payerId, forKey: .payerId)
        try c.encode(date, forKey: .date)
        try c.encode(recurringId, forKey: .recurringId)
        try c.encode(updatedAt, forKey: .updatedAt)
        // Explicit null: a re-confirmed recurring bill reuses its deterministic ID, and
        // PostgREST upsert would otherwise keep the old deleted_at.
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

nonisolated extension BudgetExpense: SyncableEntity {
    static let tableName = "budget_expenses"
}
