import Foundation

nonisolated struct RecurringExpense: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amountCents: Int
    var categoryId: UUID
    var payerId: UUID
    var dayOfMonth: Int
    var active: Bool = true
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, active
        case amountCents = "amount_cents"
        case categoryId = "category_id"
        case payerId = "payer_id"
        case dayOfMonth = "day_of_month"
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
        try c.encode(dayOfMonth, forKey: .dayOfMonth)
        try c.encode(active, forKey: .active)
        try c.encode(updatedAt, forKey: .updatedAt)
        // Explicit null so an undeleted row clears its remote tombstone.
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

nonisolated extension RecurringExpense: SyncableEntity {
    static let tableName = "budget_recurring"
}
