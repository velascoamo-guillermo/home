import Foundation

nonisolated struct MenuEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var dayOfWeek: Int
    var slot: MealSlot
    var mealId: UUID
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, slot
        case dayOfWeek = "day_of_week"
        case mealId    = "meal_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(id: UUID = UUID(), dayOfWeek: Int, slot: MealSlot, mealId: UUID,
         createdAt: Date = .now, updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.slot = slot
        self.mealId = mealId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        dayOfWeek = try c.decode(Int.self, forKey: .dayOfWeek)
        slot = try c.decode(MealSlot.self, forKey: .slot)
        mealId = try c.decode(UUID.self, forKey: .mealId)
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? .now
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? .now
        deletedAt = try? c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(dayOfWeek, forKey: .dayOfWeek)
        try c.encode(slot, forKey: .slot)
        try c.encode(mealId, forKey: .mealId)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

nonisolated extension MenuEntry: SyncableEntity {
    static let tableName = "menu_entries"
}
