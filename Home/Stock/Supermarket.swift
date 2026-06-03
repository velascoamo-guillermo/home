import Foundation

enum Supermarket: String, Codable, CaseIterable, Identifiable, Hashable {
    case carrefour
    case mercadona

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .carrefour: "Carrefour"
        case .mercadona: "Mercadona"
        }
    }
}
