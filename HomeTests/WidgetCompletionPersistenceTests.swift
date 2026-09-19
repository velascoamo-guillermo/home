import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct WidgetCompletionPersistenceTests {
    private func makeStore() async throws -> LocalStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-intent-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try await LocalStore(url: dir.appendingPathComponent("t.sqlite"))
    }

    @Test func intentStyleCompletionWritesTaskAndProductOutboxOps() async throws {
        let store = try await makeStore()
        let product = StockProduct(name: "Filters", level: .medium)
        var task = HouseholdTask(title: "Change filter",                                  intervalDays: 30, nextDueDate: .now)
        task.productId = product.id
        try await store.upsert([product], enqueue: false)
        try await store.upsert([task], enqueue: false)

        let plan = TaskCompletion.plan(for: task, stockProducts: [product])
        var updatedTask = plan.updatedTask
        updatedTask.updatedAt = .now
        try await store.upsert([updatedTask], enqueue: true)
        var updatedProduct = try #require(plan.updatedProduct)
        updatedProduct.updatedAt = .now
        try await store.upsert([updatedProduct], enqueue: true)

        let ops = try await store.pendingOps()
        #expect(ops.count == 2)
        #expect(Set(ops.map(\.tableName)) == ["household_tasks", "stock_products"])
        #expect(ops.allSatisfy { $0.kind == .update })

        let storedTasks = try await store.fetchAll(HouseholdTask.self)
        // LocalStore encodes Dates via JSONEncoder's plain `.iso8601` strategy
        // (no fractional seconds — see SyncDateCoding.swift's decode-side
        // rationale), so a round trip through storage is second-precision, not
        // sub-second-exact. Compare with a 1s tolerance rather than `==`.
        let storedNextDueDate = try #require(storedTasks.first?.nextDueDate)
        #expect(abs(storedNextDueDate.timeIntervalSince1970
                    - updatedTask.nextDueDate.timeIntervalSince1970) < 1)
        let storedProducts = try await store.fetchAll(StockProduct.self)
        #expect(storedProducts.first?.level == .low)
    }
}
