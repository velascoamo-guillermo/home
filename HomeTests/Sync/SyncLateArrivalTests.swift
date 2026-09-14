import Testing
import Foundation
@testable import Casita

/// Rows that reached Supabase long after their client `updated_at` were skipped by
/// devices whose pull cursor had already passed that timestamp.
@Suite("Sync late arrivals") @MainActor struct SyncLateArrivalTests {
    private func url() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("la-\(UUID().uuidString).sqlite")
    }

    private func blob(_ product: StockProduct, updatedAt: String) throws -> Data {
        var obj = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(product)) as? [String: Any])
        obj["updated_at"] = updatedAt
        return try JSONSerialization.data(withJSONObject: obj)
    }

    @Test("opening a store from before the cursor reset clears every pull cursor once")
    func legacyCursorsReset() async throws {
        let file = url()
        let legacy = try SQLiteDatabase(url: file)
        try await legacy.execute("CREATE TABLE sync_cursor (table_name TEXT PRIMARY KEY, cursor TEXT NOT NULL)")
        try await legacy.execute("INSERT INTO sync_cursor VALUES ('meals', '2026-08-07T06:43:14Z')")

        let store = try await LocalStore(url: file)
        #expect(try await store.cursor(for: "meals") == nil)

        let kept = Date(timeIntervalSince1970: 1_800_000_000)
        try await store.setCursor(kept, for: "meals")
        let reopened = try await LocalStore(url: file)
        #expect(try await reopened.cursor(for: "meals") == kept)
    }

    @Test("pull asks for rows slightly older than the cursor to cover in-flight writes")
    func pullOverlapsCursor() async throws {
        let store = try await LocalStore(url: url())
        let gateway = FakeGateway()
        let engine = SyncEngine(local: store, gateway: gateway)
        let cursor = Date(timeIntervalSince1970: 1_800_000_000)
        try await store.setCursor(cursor, for: "stock_products")

        try await engine.pull(table: "stock_products")

        let sinces = await gateway.pullSinces
        #expect(sinces == [cursor.addingTimeInterval(-SyncEngine.pullOverlap)])
    }

    @Test("pull with no cursor fetches everything")
    func pullWithoutCursor() async throws {
        let store = try await LocalStore(url: url())
        let gateway = FakeGateway()
        try await SyncEngine(local: store, gateway: gateway).pull(table: "stock_products")
        #expect(await gateway.pullSinces == [nil])
    }

    @Test("rows re-fetched by the overlap never move the cursor backwards")
    func cursorNeverRegresses() async throws {
        let store = try await LocalStore(url: url())
        let gateway = FakeGateway()
        let engine = SyncEngine(local: store, gateway: gateway)
        let cursor = try #require(SyncDateCoding.date(from: "2026-09-14T20:08:05Z"))
        try await store.setCursor(cursor, for: "stock_products")
        let product = StockProduct(name: "Milk", packages: 1, looseUnits: 0, unitsPerPackage: 6)
        await gateway.setPull("stock_products", [try blob(product, updatedAt: "2026-09-14T20:08:02Z")])

        try await engine.pull(table: "stock_products")

        #expect(try await store.cursor(for: "stock_products") == cursor)
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Milk"])
    }
}
