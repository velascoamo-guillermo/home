import Testing
import Foundation
@testable import Casita

@Suite("SupabaseStore – task completion + stock") @MainActor struct StockCompletionTests {

    private func makeTask(productId: UUID?) -> HouseholdTask {
        HouseholdTask(title: "Change filter", intervalDays: 30,
                      nextDueDate: Date(timeIntervalSince1970: 0), productId: productId)
    }

    @Test("completionPlan advances nextDueDate by intervalDays from now")
    func advancesDate() {
        let store = SupabaseStore()
        let plan = store.completionPlan(for: makeTask(productId: nil))
        let expected = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        #expect(abs(plan.updatedTask.nextDueDate.timeIntervalSince(expected)) < 2)
    }

    @Test("completionPlan returns .noProduct when task has no productId")
    func noProduct() {
        let store = SupabaseStore()
        let plan = store.completionPlan(for: makeTask(productId: nil))
        #expect(plan.result == .noProduct)
        #expect(plan.updatedProduct == nil)
    }

    @Test("completionPlan steps a stocked product down one level")
    func stepsDown() {
        let store = SupabaseStore()
        let product = StockProduct(name: "Filter", level: .medium)
        store.stockProducts = [product]
        let plan = store.completionPlan(for: makeTask(productId: product.id))
        #expect(plan.result == .consumed)
        #expect(plan.updatedProduct?.level == .low)
        #expect(plan.updatedProduct?.id == product.id)
    }

    @Test("completionPlan returns .outOfStock when the product is Out")
    func outOfStock() {
        let store = SupabaseStore()
        let product = StockProduct(name: "Filter", level: .out)
        store.stockProducts = [product]
        let plan = store.completionPlan(for: makeTask(productId: product.id))
        #expect(plan.result == .outOfStock(product))
        #expect(plan.updatedProduct == nil)
    }

    @Test("completionPlan returns .noProduct when productId points to missing product")
    func missingProduct() {
        let store = SupabaseStore()
        let plan = store.completionPlan(for: makeTask(productId: UUID()))
        #expect(plan.result == .noProduct)
    }
}
