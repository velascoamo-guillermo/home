import Foundation

nonisolated struct StockProduct: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var level: StockLevel
    var needed: Bool = false
    var createdAt: Date = .now
    var supermarket: Supermarket?
    var category: ProductCategory?
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    var isOnShoppingList: Bool { level.needsRestock || needed }

    func withLevel(_ level: StockLevel) -> StockProduct {
        var copy = self
        copy.level = level
        return copy
    }

    func steppedDown() -> StockProduct {
        withLevel(level.steppedDown())
    }

    func replenished() -> StockProduct {
        var copy = withLevel(.full)
        copy.needed = false
        return copy
    }

    init(id: UUID = UUID(), name: String, level: StockLevel, needed: Bool = false,
         createdAt: Date = .now, supermarket: Supermarket? = nil, category: ProductCategory? = nil,
         updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.level = level
        self.needed = needed
        self.createdAt = createdAt
        self.supermarket = supermarket
        self.category = category
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, level, needed, supermarket, category
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    // Cached rows and outbox blobs written before levels existed carry unit counts instead.
    private enum LegacyUnitKeys: String, CodingKey {
        case packages
        case loose = "loose_units"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        if let decodedLevel = try c.decodeIfPresent(StockLevel.self, forKey: .level) {
            level = decodedLevel
        } else {
            let legacy = try decoder.container(keyedBy: LegacyUnitKeys.self)
            level = StockLevel.from(
                packages: try legacy.decodeIfPresent(Int.self, forKey: .packages) ?? 0,
                looseUnits: try legacy.decodeIfPresent(Int.self, forKey: .loose) ?? 0
            )
        }
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
