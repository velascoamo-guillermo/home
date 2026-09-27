import Foundation

nonisolated enum BudgetSeed {
    static let memberNames = ["Guille", "Lu"]

    static let categoryEstimates: [(name: String, cents: Int)] = [
        ("Alquiler", 90_500), ("Seguro / comunidad", 3_000), ("Internet", 2_000),
        ("Luz", 11_000), ("Agua", 4_000), ("Supermercado", 35_000), ("Gatos", 11_000),
        ("Suscripciones", 5_000), ("Comer fuera", 4_000), ("Ocio", 3_000), ("Hogar", 5_000),
        ("Ropa y complementos", 4_000), ("Salud", 4_000), ("Otros", 4_000),
    ]

    static func members() -> [BudgetMember] {
        memberNames.enumerated().map { index, name in
            BudgetMember(id: BudgetIDs.member(name: name), name: name, sortOrder: index)
        }
    }

    static func categories() -> [BudgetCategory] {
        categoryEstimates.enumerated().map { index, entry in
            BudgetCategory(id: BudgetIDs.category(name: entry.name), name: entry.name,
                           estimateCents: entry.cents, sortOrder: index)
        }
    }
}
