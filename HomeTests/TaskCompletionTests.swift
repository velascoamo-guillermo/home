import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct TaskCompletionTests {
    private let cal = Calendar.current

    private func task(interval: Int = 7, productId: UUID? = nil, qty: Int = 1) -> HouseholdTask {
        var t = HouseholdTask(title: "t", intervalDays: interval,
                              nextDueDate: cal.date(byAdding: .day, value: -1, to: .now)!)
        t.productId = productId
        t.quantityPerCompletion = qty
        return t
    }

    @Test func reschedulesFromNowNotFromDueDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = TaskCompletion.plan(for: task(interval: 7), stockProducts: [], now: now, calendar: cal)
        #expect(plan.updatedTask.nextDueDate == cal.date(byAdding: .day, value: 7, to: now))
        #expect(plan.result == .noProduct)
        #expect(plan.updatedProduct == nil)
    }

    @Test func consumesLinkedProduct() {
        let p = StockProduct(name: "p", packages: 1, looseUnits: 0, unitsPerPackage: 2)
        let plan = TaskCompletion.plan(for: task(productId: p.id, qty: 1), stockProducts: [p])
        #expect(plan.result == .consumed)
        #expect(plan.updatedProduct?.totalUnits == 1)
    }

    @Test func outOfStockWhenInsufficient() {
        let p = StockProduct(name: "p", packages: 0, looseUnits: 1, unitsPerPackage: 1)
        let plan = TaskCompletion.plan(for: task(productId: p.id, qty: 2), stockProducts: [p])
        #expect(plan.result == .outOfStock(p))
        #expect(plan.updatedProduct == nil)
    }

    @Test func unknownProductIdIsNoProduct() {
        let plan = TaskCompletion.plan(for: task(productId: UUID()), stockProducts: [])
        #expect(plan.result == .noProduct)
    }
}
