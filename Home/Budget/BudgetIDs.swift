import Foundation

/// IDs for rows two offline devices may each create for the same logical thing, so both
/// write the same row and last-write-wins resolves it. The name formats are persisted
/// identity: changing them forks every existing row.
nonisolated enum BudgetIDs {
    static let namespace = UUID(uuid: (0x6F, 0x1C, 0x1B, 0x0E, 0x3D, 0x2A, 0x4C, 0x55,
                                       0x9A, 0x8E, 0x4B, 0x7D, 0xE0, 0xB6, 0xA1, 0xC2))

    static func member(name: String) -> UUID {
        UUID.nameBased(namespace: namespace, name: "budget-member:\(name)")
    }

    static func category(name: String) -> UUID {
        UUID.nameBased(namespace: namespace, name: "budget-category:\(name)")
    }

    static func income(memberId: UUID, month: BudgetMonth) -> UUID {
        UUID.nameBased(namespace: namespace,
                       name: "budget-income:\(memberId.uuidString.lowercased()):\(month.key)")
    }

    static func recurringExpense(recurringId: UUID, month: BudgetMonth) -> UUID {
        UUID.nameBased(namespace: namespace,
                       name: "budget-recurring:\(recurringId.uuidString.lowercased()):\(month.key)")
    }
}
