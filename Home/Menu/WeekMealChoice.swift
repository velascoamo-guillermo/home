import Foundation

struct WeekMealChoice: Decodable {
    var day: Int
    var slot: MealSlot
    var mealId: UUID?
    var title: String?

    enum CodingKeys: String, CodingKey {
        case day, slot, title
        case mealId = "meal_id"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Int.self, forKey: .day)
        slot = try c.decode(MealSlot.self, forKey: .slot)
        mealId = try? c.decodeIfPresent(UUID.self, forKey: .mealId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
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
