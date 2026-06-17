import Foundation

struct WeekMealSuggestion: Decodable {
    var day: Int
    var slot: MealSlot
    var title: String
    var products: [MealSuggestion.ProductRef]
    var servings: Int?
    var nutrition: Nutrition

    enum CodingKeys: String, CodingKey {
        case day, slot, title, products, servings, calories
        case proteinG = "protein_g"
        case carbsG   = "carbs_g"
        case fatG     = "fat_g"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Int.self, forKey: .day)
        slot = try c.decode(MealSlot.self, forKey: .slot)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        let raw = try c.decodeIfPresent([MealSuggestion.ProductRef].self, forKey: .products) ?? []
        products = raw.filter { !$0.name.isEmpty }
        servings = try c.decodeIfPresent(Int.self, forKey: .servings)
        nutrition = Nutrition(
            calories: try c.decodeIfPresent(Int.self, forKey: .calories),
            proteinG: try c.decodeIfPresent(Int.self, forKey: .proteinG),
            carbsG:   try c.decodeIfPresent(Int.self, forKey: .carbsG),
            fatG:     try c.decodeIfPresent(Int.self, forKey: .fatG)
        )
    }

    func resolveLinks(against stock: [StockProduct]) -> [MealEntry.Link] {
        products.compactMap { ref in
            guard let match = stock.first(where: {
                $0.name.compare(ref.name, options: .caseInsensitive) == .orderedSame
            }) else { return nil }
            return MealEntry.Link(product: match, quantity: ref.quantity)
        }
    }
}
