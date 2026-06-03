import Foundation

enum ProductCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case food
    case cleaning
    case hygiene
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food:     "Food"
        case .cleaning: "Cleaning"
        case .hygiene:  "Hygiene"
        case .other:    "Other"
        }
    }

    var icon: String {
        switch self {
        case .food:     "fork.knife"
        case .cleaning: "bubbles.and.sparkles"
        case .hygiene:  "hands.and.sparkles"
        case .other:    "shippingbox"
        }
    }
}
