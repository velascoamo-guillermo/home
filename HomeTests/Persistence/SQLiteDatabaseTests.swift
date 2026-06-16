import Testing
import Foundation
@testable import Home

@Suite("SQLiteDatabase") struct SQLiteDatabaseTests {
    private func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sqltest-\(UUID().uuidString).sqlite")
    }

    @Test("exec + query round-trips a row")
    func roundTrip() async throws {
        let db = try SQLiteDatabase(url: tempURL())
        try await db.execute("CREATE TABLE t (id TEXT PRIMARY KEY, n INTEGER)")
        try await db.execute("INSERT INTO t (id, n) VALUES (?, ?)", ["a", 7])
        let rows = try await db.query("SELECT id, n FROM t WHERE id = ?", ["a"])
        #expect(rows.count == 1)
        #expect(rows[0]["id"]?.text == "a")
        #expect(rows[0]["n"]?.int == 7)
    }

    @Test("transaction rolls back on error")
    func rollback() async throws {
        let db = try SQLiteDatabase(url: tempURL())
        try await db.execute("CREATE TABLE t (id TEXT PRIMARY KEY)")
        do {
            try await db.transaction { conn in
                try conn.execute("INSERT INTO t (id) VALUES (?)", ["x"])
                try conn.execute("INSERT INTO t (id) VALUES (?)", ["x"]) // PK conflict
            }
            Issue.record("Expected transaction to throw")
        } catch {
            // Expected — PK violation triggers rollback
        }
        let rows = try await db.query("SELECT id FROM t", [])
        #expect(rows.isEmpty)
    }
}
