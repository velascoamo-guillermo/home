import Foundation

// Shared between the app store and the widget intent — the single source of
// truth for what "completing a task" means.
nonisolated enum TaskCompletion {
    enum Result: Equatable {
        case consumed
        case outOfStock(StockProduct)
        case noProduct
    }

    struct Plan {
        var updatedTask: HouseholdTask
        var updatedProduct: StockProduct?
        var result: Result
    }

    static func plan(for task: HouseholdTask, stockProducts: [StockProduct],
                     now: Date = .now, calendar: Calendar = .current) -> Plan {
        var updatedTask = task
        updatedTask.nextDueDate = calendar.date(
            byAdding: .day, value: task.intervalDays, to: now
        ) ?? now

        guard let productId = task.productId,
              let product = stockProducts.first(where: { $0.id == productId }) else {
            return Plan(updatedTask: updatedTask, updatedProduct: nil, result: .noProduct)
        }

        guard let consumed = product.consuming(units: task.quantityPerCompletion) else {
            return Plan(updatedTask: updatedTask, updatedProduct: nil, result: .outOfStock(product))
        }

        return Plan(updatedTask: updatedTask, updatedProduct: consumed, result: .consumed)
    }
}
