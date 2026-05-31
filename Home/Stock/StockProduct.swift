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

    init(id: UUID = UUID(), name: String, icon: String, packages: Int,
         looseUnits: Int, unitsPerPackage: Int, createdAt: Date = .now) {
        precondition(unitsPerPackage >= 1, "unitsPerPackage must be >= 1")
        self.id = id
        self.name = name
        self.icon = icon
        self.packages = packages
        self.looseUnits = looseUnits
        self.unitsPerPackage = unitsPerPackage
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, packages
        case looseUnits = "loose_units"
        case unitsPerPackage = "units_per_package"
    }
}
