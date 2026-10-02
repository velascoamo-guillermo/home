import Testing
import Foundation
@testable import Casita

@Suite("Restore sync") @MainActor struct RestoreSyncTests {

    private func device(_ remote: InMemoryRemote) async throws -> (SyncEngine, LocalStore) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("restore-\(UUID().uuidString).sqlite")
        let local = try await LocalStore(url: url)
        return (SyncEngine(local: local, gateway: remote), local)
    }

    @Test("a restored task clears the remote tombstone so another device pulls it back")
    func taskRestoreClearsTombstone() async throws {
        let remote = InMemoryRemote()
        let (a, localA) = try await device(remote)
        let (b, localB) = try await device(remote)
        let task = HouseholdTask(title: "Bleed radiators", intervalDays: 365, nextDueDate: .now)
        try await localA.upsert([task], enqueue: true)
        try await a.push()
        try await localA.softDelete(task, enqueue: true)
        try await a.push()
        var restored = task
        restored.deletedAt = nil
        restored.updatedAt = .now
        try await localA.upsert([restored], enqueue: true)
        try await a.push()
        #expect(await remote.deletedAtIsNull(HouseholdTask.tableName, id: task.id))
        try await b.pull(table: HouseholdTask.tableName)
        #expect(try await localB.fetchAll(HouseholdTask.self).map(\.id) == [task.id])
    }

    @Test("a restored product clears the remote tombstone so another device pulls it back")
    func productRestoreClearsTombstone() async throws {
        let remote = InMemoryRemote()
        let (a, localA) = try await device(remote)
        let (b, localB) = try await device(remote)
        let product = StockProduct(name: "Oat milk", level: .low)
        try await localA.upsert([product], enqueue: true)
        try await a.push()
        try await localA.softDelete(product, enqueue: true)
        try await a.push()
        var restored = product
        restored.deletedAt = nil
        restored.updatedAt = .now
        try await localA.upsert([restored], enqueue: true)
        try await a.push()
        #expect(await remote.deletedAtIsNull(StockProduct.tableName, id: product.id))
        try await b.pull(table: StockProduct.tableName)
        #expect(try await localB.fetchAll(StockProduct.self).map(\.id) == [product.id])
    }
}
