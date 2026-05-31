import Foundation

struct StockProduct: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var packages: Int
    var looseUnits: Int
    var unitsPerPackage: Int
    var createdAt: Date = .now

    var totalUnits: Int { packages * unitsPerPackage + looseUnits }

    func consumingOneUnit() -> StockProduct? {
        guard totalUnits > 0 else { return nil }
        var copy = self
        if copy.looseUnits > 0 {
            copy.looseUnits -= 1
        } else {
            copy.packages -= 1
            copy.looseUnits = unitsPerPackage - 1
        }
        return copy
    }

    func replenished() -> StockProduct {
        var copy = self
        copy.packages += 1
        return copy
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, packages
        case looseUnits = "loose_units"
        case unitsPerPackage = "units_per_package"
        case createdAt = "created_at"
    }
}
