import Testing
import Foundation
@testable import Home

@Suite("SupabaseStore – task completion + stock") @MainActor struct StockCompletionTests {

    private func makeTask(productId: UUID?) -> HouseholdTask {
        HouseholdTask(title: "Change filter", icon: "wrench", intervalDays: 30,
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

    @Test("completionPlan consumes one unit when stock available")
    func consumes() {
        let store = SupabaseStore()
        let product = StockProduct(name: "Filter", icon: "wrench",
                                   packages: 1, looseUnits: 2, unitsPerPackage: 3)
        store.stockProducts = [product]
        let plan = store.completionPlan(for: makeTask(productId: product.id))
        #expect(plan.result == .consumed)
        #expect(plan.updatedProduct?.looseUnits == 1)
        #expect(plan.updatedProduct?.id == product.id)
    }

    @Test("completionPlan returns .outOfStock when product totalUnits == 0")
    func outOfStock() {
        let store = SupabaseStore()
        let product = StockProduct(name: "Filter", icon: "wrench",
                                   packages: 0, looseUnits: 0, unitsPerPackage: 3)
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

    private func makeTask(productId: UUID?, quantity: Int) -> HouseholdTask {
        HouseholdTask(title: "Change filter", icon: "wrench", intervalDays: 30,
                      nextDueDate: Date(timeIntervalSince1970: 0),
                      productId: productId, quantityPerCompletion: quantity)
    }

    @Test("completionPlan consumes quantityPerCompletion units")
    func consumesN() {
        let store = SupabaseStore()
        let product = StockProduct(name: "Filter", icon: "wrench",
                                   packages: 1, looseUnits: 2, unitsPerPackage: 3)
        store.stockProducts = [product]
        let plan = store.completionPlan(for: makeTask(productId: product.id, quantity: 2))
        #expect(plan.result == .consumed)
        #expect(plan.updatedProduct?.totalUnits == 3)
    }

    @Test("completionPlan blocks when quantityPerCompletion exceeds stock")
    func blocksWhenNotEnough() {
        let store = SupabaseStore()
        let product = StockProduct(name: "Filter", icon: "wrench",
                                   packages: 0, looseUnits: 1, unitsPerPackage: 3)
        store.stockProducts = [product]
        let plan = store.completionPlan(for: makeTask(productId: product.id, quantity: 2))
        #expect(plan.result == .outOfStock(product))
        #expect(plan.updatedProduct == nil)
    }
}
