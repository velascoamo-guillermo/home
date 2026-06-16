import Foundation

struct MealProduct: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var mealId: UUID
    var productId: UUID
    var quantity: Int = 1
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case mealId    = "meal_id"
        case productId = "product_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

extension MealProduct: SyncableEntity {
    static let tableName = "meal_products"
}
