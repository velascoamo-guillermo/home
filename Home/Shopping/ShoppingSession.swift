import Foundation
import Observation

// Checked state is a local shopping-session preference — it deliberately
// bypasses the sync/outbox path, like CalendarSelectionStore.
@Observable
final class ShoppingSession {
    static let key = "shopping.checked.v1"

    private let defaults: UserDefaults
    private(set) var checkedIds: Set<UUID>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            checkedIds = ids
        } else {
            checkedIds = []
        }
    }

    func isChecked(_ id: UUID) -> Bool {
        checkedIds.contains(id)
    }

    func toggle(_ id: UUID) {
        if checkedIds.contains(id) {
            checkedIds.remove(id)
        } else {
            checkedIds.insert(id)
        }
        persist()
    }

    func prune(validIds: Set<UUID>) {
        let pruned = checkedIds.intersection(validIds)
        guard pruned != checkedIds else { return }
        checkedIds = pruned
        persist()
    }

    func uncheck(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        checkedIds.subtract(ids)
        persist()
    }

    nonisolated static func quickAddProduct(named rawName: String) -> StockProduct? {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return StockProduct(name: name,
                            packages: 0, looseUnits: 0, unitsPerPackage: 1)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(checkedIds) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
