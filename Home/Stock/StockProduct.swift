import Foundation

nonisolated struct StockProduct: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var level: StockLevel
    var packages: Int
    var looseUnits: Int
    var unitsPerPackage: Int
    var needed: Bool = false
    var createdAt: Date = .now
    var supermarket: Supermarket?
    var category: ProductCategory?
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    nonisolated var totalUnits: Int { packages * unitsPerPackage + looseUnits }

    func withLevel(_ level: StockLevel) -> StockProduct {
        var copy = self
        copy.level = level
        return copy
    }

    func steppedDown() -> StockProduct {
        withLevel(level.steppedDown())
    }

    func consuming(units n: Int) -> StockProduct? {
        guard n >= 1, totalUnits >= n else { return nil }
        var copy = self
        var remaining = n
        while remaining > 0 {
            if copy.looseUnits > 0 {
                copy.looseUnits -= 1
            } else {
                copy.packages -= 1
                copy.looseUnits = copy.unitsPerPackage - 1
            }
            remaining -= 1
        }
        copy.level = StockLevel.from(packages: copy.packages, looseUnits: copy.looseUnits)
        return copy
    }

    func consumingOneUnit() -> StockProduct? { consuming(units: 1) }

    func replenished() -> StockProduct {
        var copy = self
        copy.packages += 1
        copy.level = .full
        copy.needed = false
        return copy
    }

    func emptied() -> StockProduct {
        var copy = self
        copy.packages = 0
        copy.looseUnits = 0
        copy.level = .out
        return copy
    }

    init(id: UUID = UUID(), name: String, level: StockLevel, needed: Bool = false,
         createdAt: Date = .now, supermarket: Supermarket? = nil, category: ProductCategory? = nil,
         updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.init(id: id, name: name, packages: 0, looseUnits: 0, unitsPerPackage: 1,
                  needed: needed, createdAt: createdAt, supermarket: supermarket,
                  category: category, updatedAt: updatedAt, deletedAt: deletedAt)
        self.level = level
    }

    init(id: UUID = UUID(), name: String, packages: Int,
         looseUnits: Int, unitsPerPackage: Int, needed: Bool = false, createdAt: Date = .now,
         supermarket: Supermarket? = nil, category: ProductCategory? = nil,
         updatedAt: Date = .now, deletedAt: Date? = nil) {
        precondition(unitsPerPackage >= 1, "unitsPerPackage must be >= 1")
        self.id = id
        self.name = name
        self.level = StockLevel.from(packages: packages, looseUnits: looseUnits)
        self.packages = packages
        self.looseUnits = looseUnits
        self.unitsPerPackage = unitsPerPackage
        self.needed = needed
        self.createdAt = createdAt
        self.supermarket = supermarket
        self.category = category
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, level, packages, needed, supermarket, category
        case looseUnits      = "loose_units"
        case unitsPerPackage = "units_per_package"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case deletedAt       = "deleted_at"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        packages = try c.decodeIfPresent(Int.self, forKey: .packages) ?? 0
        looseUnits = try c.decodeIfPresent(Int.self, forKey: .looseUnits) ?? 0
        unitsPerPackage = try c.decodeIfPresent(Int.self, forKey: .unitsPerPackage) ?? 1
        level = try c.decodeIfPresent(StockLevel.self, forKey: .level)
            ?? StockLevel.from(packages: packages, looseUnits: looseUnits)
        needed = try c.decodeIfPresent(Bool.self, forKey: .needed) ?? false
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? .now
        supermarket = try c.decodeIfPresent(Supermarket.self, forKey: .supermarket)
        category = try c.decodeIfPresent(ProductCategory.self, forKey: .category)
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? .now
        deletedAt = try? c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

nonisolated extension StockProduct: SyncableEntity {
    static let tableName = "stock_products"
}
