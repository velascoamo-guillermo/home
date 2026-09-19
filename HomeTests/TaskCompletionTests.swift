import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct TaskCompletionTests {
    private let cal = Calendar.current

    private func task(interval: Int = 7, productId: UUID? = nil) -> HouseholdTask {
        var t = HouseholdTask(title: "t", intervalDays: interval,
                              nextDueDate: cal.date(byAdding: .day, value: -1, to: .now)!)
        t.productId = productId
        return t
    }

    @Test func reschedulesFromNowNotFromDueDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = TaskCompletion.plan(for: task(interval: 7), stockProducts: [], now: now, calendar: cal)
        #expect(plan.updatedTask.nextDueDate == cal.date(byAdding: .day, value: 7, to: now))
        #expect(plan.result == .noProduct)
        #expect(plan.updatedProduct == nil)
    }

    @Test func fullStepsDownToMedium() {
        let p = StockProduct(name: "p", level: .full)
        let plan = TaskCompletion.plan(for: task(productId: p.id), stockProducts: [p])
        #expect(plan.result == .consumed)
        #expect(plan.updatedProduct?.level == .medium)
        #expect(plan.updatedProduct?.id == p.id)
    }

    @Test func lowStepsDownToOut() {
        let p = StockProduct(name: "p", level: .low)
        let plan = TaskCompletion.plan(for: task(productId: p.id), stockProducts: [p])
        #expect(plan.result == .consumed)
        #expect(plan.updatedProduct?.level == .out)
    }

    @Test func outIsOutOfStockAndLeavesProductUntouched() {
        let p = StockProduct(name: "p", level: .out)
        let plan = TaskCompletion.plan(for: task(productId: p.id), stockProducts: [p])
        #expect(plan.result == .outOfStock(p))
        #expect(plan.updatedProduct == nil)
    }

    @Test func quantityPerCompletionNoLongerChangesTheStep() {
        let p = StockProduct(name: "p", level: .full)
        var t = task(productId: p.id)
        t.quantityPerCompletion = 5
        let plan = TaskCompletion.plan(for: t, stockProducts: [p])
        #expect(plan.updatedProduct?.level == .medium)
    }

    @Test func unknownProductIdIsNoProduct() {
        let plan = TaskCompletion.plan(for: task(productId: UUID()), stockProducts: [])
        #expect(plan.result == .noProduct)
    }
}
