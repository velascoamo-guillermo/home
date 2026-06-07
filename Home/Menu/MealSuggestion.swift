import Foundation

struct MealSuggestion: Decodable {
    struct ProductRef: Decodable {
        var name: String
        var quantity: Int

        enum CodingKeys: String, CodingKey { case name, quantity }

        init(name: String, quantity: Int) {
            self.name = name
            self.quantity = quantity
        }

        nonisolated init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            quantity = max(1, try c.decodeIfPresent(Int.self, forKey: .quantity) ?? 1)
        }
    }

    var title: String
    var products: [ProductRef]
    var servings: Int?
    var nutrition: Nutrition

    enum CodingKeys: String, CodingKey {
        case title, products, servings, calories
        case proteinG = "protein_g"
        case carbsG   = "carbs_g"
        case fatG     = "fat_g"
    }

    init(title: String, products: [ProductRef], servings: Int?, nutrition: Nutrition) {
        self.title = title
        self.products = products
        self.servings = servings
        self.nutrition = nutrition
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        let raw = try c.decodeIfPresent([ProductRef].self, forKey: .products) ?? []
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

enum SuggestionError: LocalizedError {
    case parseError
    case networkError(Error)
    case invalidResponse(Int)

    var errorDescription: String? {
        switch self {
        case .parseError:             return "No se pudo leer la sugerencia."
        case .networkError(let e):    return "Error de red: \(e.localizedDescription)"
        case .invalidResponse(let c): return "La sugerencia falló (estado \(c))."
        }
    }
}
