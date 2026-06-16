import Foundation

enum MealSlot: String, Codable, CaseIterable, Hashable {
    case lunch
    case dinner

    var displayName: String {
        switch self {
        case .lunch:  return "Almuerzo"
        case .dinner: return "Cena"
        }
    }
}

nonisolated struct Nutrition: Hashable {
    var calories: Int?
    var proteinG: Int?
    var carbsG: Int?
    var fatG: Int?

    var hasAnyValue: Bool {
        calories != nil || proteinG != nil || carbsG != nil || fatG != nil
    }
}

struct Meal: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var dayOfWeek: Int
    var slot: MealSlot
    var title: String = ""
    var servings: Int?
    var nutrition: Nutrition = Nutrition()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, slot, title, servings, calories
        case dayOfWeek = "day_of_week"
        case proteinG  = "protein_g"
        case carbsG    = "carbs_g"
        case fatG      = "fat_g"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(id: UUID = UUID(), dayOfWeek: Int, slot: MealSlot, title: String = "",
         servings: Int? = nil, nutrition: Nutrition = Nutrition(), createdAt: Date = .now,
         updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.slot = slot
        self.title = title
        self.servings = servings
        self.nutrition = nutrition
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        dayOfWeek = try c.decode(Int.self, forKey: .dayOfWeek)
        slot = try c.decode(MealSlot.self, forKey: .slot)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        servings = try c.decodeIfPresent(Int.self, forKey: .servings)
        nutrition = Nutrition(
            calories: try c.decodeIfPresent(Int.self, forKey: .calories),
            proteinG: try c.decodeIfPresent(Int.self, forKey: .proteinG),
            carbsG:   try c.decodeIfPresent(Int.self, forKey: .carbsG),
            fatG:     try c.decodeIfPresent(Int.self, forKey: .fatG)
        )
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? .now
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? .now
        deletedAt = try? c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(dayOfWeek, forKey: .dayOfWeek)
        try c.encode(slot, forKey: .slot)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(servings, forKey: .servings)
        try c.encodeIfPresent(nutrition.calories, forKey: .calories)
        try c.encodeIfPresent(nutrition.proteinG, forKey: .proteinG)
        try c.encodeIfPresent(nutrition.carbsG, forKey: .carbsG)
        try c.encodeIfPresent(nutrition.fatG, forKey: .fatG)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

extension Meal: SyncableEntity {
    static let tableName = "meals"
}
