import Testing
import Foundation
@testable import Home

@Suite("Outbox behavior") struct OutboxTests {
    private func make() async throws -> LocalStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ob-\(UUID().uuidString).sqlite")
        return try await LocalStore(url: url)
    }
    private func product(_ id: UUID, _ name: String) -> StockProduct {
        StockProduct(id: id, name: name, icon: "i", packages: 1, looseUnits: 0, unitsPerPackage: 6)
    }

    @Test("two edits to same entity coalesce into one op")
    func coalesce() async throws {
        let store = try await make()
        let id = UUID()
        try await store.upsert([product(id, "Milk")], enqueue: true)
        try await store.upsert([product(id, "Milk 2")], enqueue: true)
        let ops = try await store.pendingOps()
        #expect(ops.count == 1)
    }

    @Test("recordOpFailure increments attempts and stores message")
    func failure() async throws {
        let store = try await make()
        try await store.upsert([product(UUID(), "Milk")], enqueue: true)
        let seq = try await store.pendingOps()[0].seq
        try await store.recordOpFailure(seq: seq, error: "boom")
        let op = try await store.pendingOps()[0]
        #expect(op.attempts == 1)
        #expect(op.lastError == "boom")
    }

    @Test("deleteOp removes the op")
    func remove() async throws {
        let store = try await make()
        try await store.upsert([product(UUID(), "Milk")], enqueue: true)
        let seq = try await store.pendingOps()[0].seq
        try await store.deleteOp(seq: seq)
        #expect(try await store.pendingOps().isEmpty)
    }
}
