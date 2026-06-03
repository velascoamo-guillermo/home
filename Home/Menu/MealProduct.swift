import Foundation

struct MealProduct: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var mealId: UUID
    var productId: UUID
    var quantity: Int = 1

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case mealId    = "meal_id"
        case productId = "product_id"
    }
}
