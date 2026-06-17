# Offline-First Sync Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app fully usable offline — all 9 non-file entities read/write to a local SQLite store first, and a sync engine reconciles with Supabase (last-write-wins) when connectivity returns.

**Architecture:** A SQLite `LocalStore` (system `libsqlite3`, no third-party dep) is the durable source of truth. `SupabaseStore` stays the `@Observable` facade whose arrays are hydrated from `LocalStore`; mutations are optimistic and transactional (entity row + outbox op in one transaction). A `SyncEngine` drains the outbox to Supabase and pulls changed rows, reconciling by `updated_at`. Deletes are soft (`deleted_at` tombstones). A `RemoteGateway` protocol isolates Supabase so sync logic is unit-testable without a network.

**Tech Stack:** Swift 6 (strict concurrency, `@MainActor` default), Swift Testing (`import Testing`), `libsqlite3`, `Network.NWPathMonitor`, Supabase Swift SDK, Supabase (Postgres) migrations.

**Spec:** `docs/superpowers/specs/2026-06-16-offline-first-sync-design.md`

---

## File Structure

**New files:**
- `Home/Shared/Persistence/SyncableEntity.swift` — protocol all synced models conform to.
- `Home/Shared/Persistence/SQLiteDatabase.swift` — low-level `actor` wrapper over `libsqlite3` (open, exec, prepared statements, transactions).
- `Home/Shared/Persistence/LocalStore.swift` — generic entity CRUD + outbox + cursor, built on `SQLiteDatabase`.
- `Home/Shared/Persistence/Outbox.swift` — `OutboxOp` model + op enum (lives with LocalStore’s outbox API; pure types).
- `Home/Shared/Sync/Reachability.swift` — `NWPathMonitor` → `AsyncStream<Bool>` + `@MainActor` `isOnline`.
- `Home/Shared/Sync/RemoteGateway.swift` — protocol + `SupabaseGateway` implementation.
- `Home/Shared/Sync/SyncEngine.swift` — push + pull/reconcile orchestration.

**Modified files:**
- All 9 entity models (add `updatedAt`/`deletedAt`, conform to `SyncableEntity`).
- `Home/Shared/Services/SupabaseStore.swift` — hydrate from LocalStore, optimistic mutations.
- `Home/ContentView.swift` — loading gate no longer blocks on network.
- `Home/Home.entitlements` / `HomeWidget/HomeWidget.entitlements` — App Group (Task 12).
- New Supabase migration under `supabase/migrations/`.

**Test files (new):**
- `HomeTests/Persistence/SyncableEntityTests.swift`
- `HomeTests/Persistence/SQLiteDatabaseTests.swift`
- `HomeTests/Persistence/LocalStoreTests.swift`
- `HomeTests/Persistence/OutboxTests.swift`
- `HomeTests/Sync/SyncEnginePushTests.swift`
- `HomeTests/Sync/SyncEnginePullTests.swift`

---

## Conventions used in every task

- Tests: `import Testing` + `@testable import Home`, `@Suite`/`@Test`/`#expect` (match existing `HomeTests`).
- Build/test verification: Xcode `Cmd+U` (no CLI build exists per CLAUDE.md). Where a step says "Run tests", run the named suite in Xcode and confirm pass/fail. **Build must be zero-error before any commit (CLAUDE.md).**
- Swift 6: every new type is `@MainActor` by default unless marked `actor`/`nonisolated`. SQLite access is confined to the `SQLiteDatabase` actor.
- Commit messages: Conventional Commits, English.

---

## Task 1: `SyncableEntity` protocol

**Files:**
- Create: `Home/Shared/Persistence/SyncableEntity.swift`
- Test: `HomeTests/Persistence/SyncableEntityTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Home

@Suite("SyncableEntity") struct SyncableEntityTests {
    @Test("StockProduct exposes table name and sync timestamps")
    func conformance() {
        var p = StockProduct(name: "Milk", icon: "i", packages: 1, looseUnits: 0, unitsPerPackage: 6)
        #expect(StockProduct.tableName == "stock_products")
        p.deletedAt = .now
        #expect(p.deletedAt != nil)
        #expect(p.updatedAt <= Date.now.addingTimeInterval(1))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run suite `SyncableEntity` in Xcode.
Expected: FAIL — `StockProduct.tableName` / `deletedAt` do not exist.

- [ ] **Step 3: Create the protocol**

```swift
// Home/Shared/Persistence/SyncableEntity.swift
import Foundation

/// A model that can live in LocalStore and sync to a Supabase table.
/// Implemented by structs whose primary key is a client-generated UUID.
protocol SyncableEntity: Codable, Identifiable, Sendable where ID == UUID {
    static var tableName: String { get }
    var id: UUID { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}
```

(Step 4 lives in Task 2 — models conform there. This step only defines the protocol.)

- [ ] **Step 4: Run test to verify it still fails (no conformances yet)**

Expected: FAIL — compile error, `StockProduct` does not conform. This is expected; Task 2 makes it pass. Do **not** commit a red build. Proceed directly to Task 2 and commit them together.

---

## Task 2: Add `updatedAt`/`deletedAt` to all 9 models + conform to `SyncableEntity`

Each model gets two new stored properties with defaults, two `CodingKeys` cases, and a one-line conformance + `tableName`. Defaults keep all existing initializers/call-sites compiling unchanged.

**Files (modify each):**
- `Home/Stock/StockProduct.swift` — table `stock_products`
- `Home/Pets/Pet.swift` (or wherever `Pet` is) — table `pets`
- Veterinarian model — table `veterinarian`
- Appointment model — table `appointments`
- ClinicalEntry model — table `clinical_entries`
- PetEvent model — table `pet_events`
- HouseholdTask model — table `household_tasks`
- TaskSection model — table `task_sections`
- Meal model — table `meals`
- MealProduct model — table `meal_products`

> Locate exact files first: `grep -rln "struct Pet\b\|struct Veterinarian\|struct Appointment\|struct ClinicalEntry\|struct PetEvent\|struct HouseholdTask\|struct TaskSection\|struct Meal\b\|struct MealProduct" Home --include=*.swift`

- [ ] **Step 1: Edit `StockProduct` (worked example — apply the same shape to all 9)**

Add properties (after `createdAt`):

```swift
    var updatedAt: Date = .now
    var deletedAt: Date? = nil
```

Add to the `init` signature + body (keep defaults so existing callers don’t change):

```swift
    init(id: UUID = UUID(), name: String, icon: String, packages: Int,
         looseUnits: Int, unitsPerPackage: Int, createdAt: Date = .now,
         supermarket: Supermarket? = nil, category: ProductCategory? = nil,
         updatedAt: Date = .now, deletedAt: Date? = nil) {
        precondition(unitsPerPackage >= 1, "unitsPerPackage must be >= 1")
        self.id = id; self.name = name; self.icon = icon
        self.packages = packages; self.looseUnits = looseUnits
        self.unitsPerPackage = unitsPerPackage; self.createdAt = createdAt
        self.supermarket = supermarket; self.category = category
        self.updatedAt = updatedAt; self.deletedAt = deletedAt
    }
```

Add to `CodingKeys`:

```swift
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
```

Add conformance + table name:

```swift
extension StockProduct: SyncableEntity {
    static let tableName = "stock_products"
}
```

- [ ] **Step 2: Repeat Step 1 for the other 8 models**

For each model file, apply exactly the same change:
1. Add `var updatedAt: Date = .now` and `var deletedAt: Date? = nil`.
2. If the model has an explicit `init`, add `updatedAt: Date = .now, deletedAt: Date? = nil` params + assignments. If it relies on the memberwise init, no init edit is needed.
3. If the model has explicit `CodingKeys`, add `case updatedAt = "updated_at"` and `case deletedAt = "deleted_at"`. If it has no `CodingKeys` (uses default camelCase keys), add an explicit `CodingKeys` enum mapping the snake_case fields, OR rely on the SDK decoder config — **check the existing file**: most models here use explicit snake_case `CodingKeys`, so add the two cases.
4. Add `extension <Model>: SyncableEntity { static let tableName = "<table>" }` using the table names listed above.

> `MealProduct`/`Meal`: verify their real property names and CodingKeys before editing (see `Home/Menu/`). The two added fields and conformance are identical.

- [ ] **Step 3: Build**

Xcode `Cmd+B`. Expected: zero errors. The `SyncableEntity` test from Task 1 now compiles.

- [ ] **Step 4: Run tests**

Run suites `SyncableEntity` + the full existing `HomeTests`. Expected: all PASS (defaults preserve existing behavior; existing model/codable tests unaffected).

- [ ] **Step 5: Commit**

```bash
git add Home/Shared/Persistence/SyncableEntity.swift HomeTests/Persistence/SyncableEntityTests.swift Home
git commit -m "feat: SyncableEntity protocol with updated_at/deleted_at on synced models"
```

---

## Task 3: `SQLiteDatabase` actor (low-level libsqlite3 wrapper)

**Files:**
- Create: `Home/Shared/Persistence/SQLiteDatabase.swift`
- Test: `HomeTests/Persistence/SQLiteDatabaseTests.swift`

> Add `import SQLite3` (system module, no SwiftPM/CocoaPods dependency). Use `SQLITE_TRANSIENT` for bound text/blobs.

- [ ] **Step 1: Write the failing test**

```swift
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
        let db = try await SQLiteDatabase(url: tempURL())
        try await db.execute("CREATE TABLE t (id TEXT PRIMARY KEY, n INTEGER)")
        try await db.execute("INSERT INTO t (id, n) VALUES (?, ?)", ["a", 7])
        let rows = try await db.query("SELECT id, n FROM t WHERE id = ?", ["a"])
        #expect(rows.count == 1)
        #expect(rows[0]["id"]?.text == "a")
        #expect(rows[0]["n"]?.int == 7)
    }

    @Test("transaction rolls back on error")
    func rollback() async throws {
        let db = try await SQLiteDatabase(url: tempURL())
        try await db.execute("CREATE TABLE t (id TEXT PRIMARY KEY)")
        await #expect(throws: (any Error).self) {
            try await db.transaction { conn in
                try conn.execute("INSERT INTO t (id) VALUES (?)", ["x"])
                try conn.execute("INSERT INTO t (id) VALUES (?)", ["x"]) // PK conflict
            }
        }
        let rows = try await db.query("SELECT id FROM t", [])
        #expect(rows.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run suite `SQLiteDatabase`. Expected: FAIL — `SQLiteDatabase` undefined.

- [ ] **Step 3: Implement the wrapper**

```swift
// Home/Shared/Persistence/SQLiteDatabase.swift
import Foundation
import SQLite3

/// A bound SQLite value (the subset we store).
enum SQLValue: Sendable, Equatable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case null

    var text: String?  { if case .text(let v)  = self { return v } else { return nil } }
    var int: Int?      { if case .int(let v)   = self { return v } else { return nil } }
    var double: Double?{ if case .double(let v)= self { return v } else { return nil } }
    var blob: Data?    { if case .blob(let v)  = self { return v } else { return nil } }
    var isNull: Bool   { if case .null = self { return true } else { return false } }
}

/// Literals usable as bind parameters.
protocol SQLBindable { var sqlValue: SQLValue { get } }
extension String: SQLBindable { var sqlValue: SQLValue { .text(self) } }
extension Int:    SQLBindable { var sqlValue: SQLValue { .int(self) } }
extension Double: SQLBindable { var sqlValue: SQLValue { .double(self) } }
extension Data:   SQLBindable { var sqlValue: SQLValue { .blob(self) } }

enum SQLiteError: Error { case open(Int32), prepare(String), step(Int32, String) }

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Serializes all access to a single sqlite3 handle. SQLite C types are not
/// Sendable; actor isolation keeps every call on one executor.
actor SQLiteDatabase {
    /// Synchronous connection facade passed into `transaction` closures.
    final class Connection {
        fileprivate let handle: OpaquePointer
        fileprivate init(_ h: OpaquePointer) { handle = h }

        func execute(_ sql: String, _ params: [SQLBindable?] = []) throws {
            let stmt = try prepare(sql, params)
            defer { sqlite3_finalize(stmt) }
            let rc = sqlite3_step(stmt)
            guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
                throw SQLiteError.step(rc, String(cString: sqlite3_errmsg(handle)))
            }
        }

        func query(_ sql: String, _ params: [SQLBindable?] = []) throws -> [[String: SQLValue]] {
            let stmt = try prepare(sql, params)
            defer { sqlite3_finalize(stmt) }
            var out: [[String: SQLValue]] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                var row: [String: SQLValue] = [:]
                for i in 0..<sqlite3_column_count(stmt) {
                    let name = String(cString: sqlite3_column_name(stmt, i))
                    switch sqlite3_column_type(stmt, i) {
                    case SQLITE_INTEGER: row[name] = .int(Int(sqlite3_column_int64(stmt, i)))
                    case SQLITE_FLOAT:   row[name] = .double(sqlite3_column_double(stmt, i))
                    case SQLITE_TEXT:    row[name] = .text(String(cString: sqlite3_column_text(stmt, i)))
                    case SQLITE_BLOB:
                        if let p = sqlite3_column_blob(stmt, i) {
                            row[name] = .blob(Data(bytes: p, count: Int(sqlite3_column_bytes(stmt, i))))
                        } else { row[name] = .blob(Data()) }
                    default: row[name] = .null
                    }
                }
                out.append(row)
            }
            return out
        }

        private func prepare(_ sql: String, _ params: [SQLBindable?]) throws -> OpaquePointer {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
                throw SQLiteError.prepare(String(cString: sqlite3_errmsg(handle)))
            }
            for (idx, p) in params.enumerated() {
                let pos = Int32(idx + 1)
                switch p?.sqlValue ?? .null {
                case .text(let v):   sqlite3_bind_text(stmt, pos, v, -1, SQLITE_TRANSIENT)
                case .int(let v):    sqlite3_bind_int64(stmt, pos, Int64(v))
                case .double(let v): sqlite3_bind_double(stmt, pos, v)
                case .blob(let v):   v.withUnsafeBytes { sqlite3_bind_blob(stmt, pos, $0.baseAddress, Int32(v.count), SQLITE_TRANSIENT) }
                case .null:          sqlite3_bind_null(stmt, pos)
                }
            }
            return stmt
        }
    }

    private let conn: Connection

    init(url: URL) throws {
        var handle: OpaquePointer?
        let rc = sqlite3_open(url.path, &handle)
        guard rc == SQLITE_OK, let handle else { throw SQLiteError.open(rc) }
        sqlite3_exec(handle, "PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;", nil, nil, nil)
        conn = Connection(handle)
    }

    func execute(_ sql: String, _ params: [SQLBindable?] = []) throws {
        try conn.execute(sql, params)
    }

    func query(_ sql: String, _ params: [SQLBindable?] = []) throws -> [[String: SQLValue]] {
        try conn.query(sql, params)
    }

    /// Runs `body` inside BEGIN/COMMIT; ROLLBACK on any thrown error.
    func transaction<T>(_ body: (Connection) throws -> T) throws -> T {
        try conn.execute("BEGIN")
        do {
            let result = try body(conn)
            try conn.execute("COMMIT")
            return result
        } catch {
            try? conn.execute("ROLLBACK")
            throw error
        }
    }

    func userVersion() throws -> Int { try query("PRAGMA user_version", []).first?["user_version"]?.int ?? 0 }
    func setUserVersion(_ v: Int) throws { try execute("PRAGMA user_version = \(v)") }
}
```

- [ ] **Step 4: Run tests**

Run suite `SQLiteDatabase`. Expected: PASS (round-trip + rollback).

- [ ] **Step 5: Commit**

```bash
git add Home/Shared/Persistence/SQLiteDatabase.swift HomeTests/Persistence/SQLiteDatabaseTests.swift
git commit -m "feat: SQLiteDatabase actor wrapper over libsqlite3"
```

---

## Task 4: `Outbox` types

**Files:**
- Create: `Home/Shared/Persistence/Outbox.swift`

This task introduces pure types only (used by Tasks 5–7). No standalone test; exercised by `OutboxTests` in Task 6 and `LocalStoreTests` in Task 5.

- [ ] **Step 1: Create the types**

```swift
// Home/Shared/Persistence/Outbox.swift
import Foundation

enum OutboxOpKind: String, Sendable, Codable { case insert, update, delete }

/// A pending mutation to replay against Supabase, drained in `seq` order.
struct OutboxOp: Sendable, Identifiable {
    var seq: Int          // assigned by SQLite AUTOINCREMENT
    var kind: OutboxOpKind
    var tableName: String
    var entityId: UUID
    var payload: Data     // JSON blob of the full entity row (empty for pure-delete fallback)
    var updatedAt: Date
    var attempts: Int
    var lastError: String?

    var id: Int { seq }
}
```

- [ ] **Step 2: Build**

Xcode `Cmd+B`. Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add Home/Shared/Persistence/Outbox.swift
git commit -m "feat: OutboxOp model for pending sync mutations"
```

---

## Task 5: `LocalStore` — schema bootstrap + generic entity CRUD

**Files:**
- Create: `Home/Shared/Persistence/LocalStore.swift`
- Test: `HomeTests/Persistence/LocalStoreTests.swift`

Schema (single generic `entities` table keyed by `(table_name, id)`, plus `outbox` and `sync_cursor`):

```sql
CREATE TABLE IF NOT EXISTS entities (
  table_name TEXT NOT NULL,
  id         TEXT NOT NULL,
  updated_at TEXT NOT NULL,   -- iso8601
  deleted_at TEXT,            -- iso8601, nullable tombstone
  payload    BLOB NOT NULL,   -- entity JSON
  PRIMARY KEY (table_name, id)
);
CREATE INDEX IF NOT EXISTS idx_entities_sync ON entities(table_name, updated_at);

CREATE TABLE IF NOT EXISTS outbox (
  seq        INTEGER PRIMARY KEY AUTOINCREMENT,
  kind       TEXT NOT NULL,
  table_name TEXT NOT NULL,
  entity_id  TEXT NOT NULL,
  payload    BLOB NOT NULL,
  updated_at TEXT NOT NULL,
  attempts   INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);

CREATE TABLE IF NOT EXISTS sync_cursor (
  table_name TEXT PRIMARY KEY,
  cursor     TEXT NOT NULL   -- iso8601 max updated_at pulled
);
```

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Home

@Suite("LocalStore") struct LocalStoreTests {
    private func make() async throws -> LocalStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ls-\(UUID().uuidString).sqlite")
        return try await LocalStore(url: url)
    }
    private func product(_ name: String) -> StockProduct {
        StockProduct(name: name, icon: "i", packages: 1, looseUnits: 0, unitsPerPackage: 6)
    }

    @Test("upsert then fetchAll returns the row")
    func upsertFetch() async throws {
        let store = try await make()
        try await store.upsert([product("Milk")], enqueue: false)
        let all = try await store.fetchAll(StockProduct.self)
        #expect(all.map(\.name) == ["Milk"])
    }

    @Test("fetchAll excludes tombstoned rows")
    func excludesTombstones() async throws {
        let store = try await make()
        let p = product("Milk")
        try await store.upsert([p], enqueue: false)
        try await store.softDelete(p, enqueue: false)
        #expect(try await store.fetchAll(StockProduct.self).isEmpty)
    }

    @Test("optimistic mutate writes entity AND outbox atomically")
    func mutateEnqueues() async throws {
        let store = try await make()
        try await store.upsert([product("Milk")], enqueue: true)
        let pending = try await store.pendingOps()
        #expect(pending.count == 1)
        #expect(pending[0].tableName == "stock_products")
        #expect(pending[0].kind == .update)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run suite `LocalStore`. Expected: FAIL — `LocalStore` undefined.

- [ ] **Step 3: Implement LocalStore (entity CRUD + cursor; outbox API stubbed minimally for this task’s tests)**

```swift
// Home/Shared/Persistence/LocalStore.swift
import Foundation

/// Durable local source of truth. Wraps SQLiteDatabase, maps SyncableEntity
/// structs <-> rows, and owns the outbox + per-table sync cursor.
actor LocalStore {
    private let db: SQLiteDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let iso = ISO8601DateFormatter()

    init(url: URL) async throws {
        db = try SQLiteDatabase(url: url)
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        try await Self.migrate(db)
    }

    private static func migrate(_ db: SQLiteDatabase) async throws {
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS entities (
              table_name TEXT NOT NULL, id TEXT NOT NULL,
              updated_at TEXT NOT NULL, deleted_at TEXT,
              payload BLOB NOT NULL, PRIMARY KEY (table_name, id));
            """)
        try await db.execute("CREATE INDEX IF NOT EXISTS idx_entities_sync ON entities(table_name, updated_at)")
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS outbox (
              seq INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
              table_name TEXT NOT NULL, entity_id TEXT NOT NULL, payload BLOB NOT NULL,
              updated_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT);
            """)
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS sync_cursor (
              table_name TEXT PRIMARY KEY, cursor TEXT NOT NULL);
            """)
    }

    // MARK: Entity CRUD

    /// Insert/replace `items`. When `enqueue` is true, append an `update` outbox
    /// op per item in the SAME transaction (optimistic mutation path).
    func upsert<T: SyncableEntity>(_ items: [T], enqueue: Bool) throws {
        let rows = try items.map { item -> (T, Data) in (item, try encoder.encode(item)) }
        try db.transaction { conn in
            for (item, blob) in rows {
                try conn.execute("""
                    INSERT INTO entities (table_name, id, updated_at, deleted_at, payload)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(table_name, id) DO UPDATE SET
                      updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, payload=excluded.payload;
                    """, [T.tableName, item.id.uuidString, iso.string(from: item.updatedAt),
                          item.deletedAt.map { iso.string(from: $0) }, blob])
                if enqueue {
                    try Self.appendOp(conn, kind: .update, table: T.tableName,
                                      id: item.id, payload: blob, updatedAt: item.updatedAt, iso: iso)
                }
            }
        }
    }

    /// Tombstone an entity (sets deleted_at = now, bumps updated_at). Optionally enqueues a delete op.
    func softDelete<T: SyncableEntity>(_ item: T, enqueue: Bool, now: Date = .now) throws {
        var tomb = item
        tomb.deletedAt = now
        tomb.updatedAt = now
        let blob = try encoder.encode(tomb)
        try db.transaction { conn in
            try conn.execute("""
                UPDATE entities SET updated_at=?, deleted_at=?, payload=? WHERE table_name=? AND id=?;
                """, [iso.string(from: now), iso.string(from: now), blob, T.tableName, item.id.uuidString])
            if enqueue {
                try Self.appendOp(conn, kind: .delete, table: T.tableName,
                                  id: item.id, payload: blob, updatedAt: now, iso: iso)
            }
        }
    }

    func fetchAll<T: SyncableEntity>(_ type: T.Type) throws -> [T] {
        let rows = try db.query("""
            SELECT payload FROM entities WHERE table_name=? AND deleted_at IS NULL ORDER BY updated_at DESC;
            """, [T.tableName])
        return try rows.compactMap { row in
            guard let blob = row["payload"]?.blob else { return nil }
            return try decoder.decode(T.self, from: blob)
        }
    }

    // MARK: Outbox (used by SyncEngine)

    func pendingOps() throws -> [OutboxOp] {
        let rows = try db.query("""
            SELECT seq, kind, table_name, entity_id, payload, updated_at, attempts, last_error
            FROM outbox ORDER BY seq ASC;
            """, [])
        return rows.compactMap { row in
            guard let seq = row["seq"]?.int,
                  let kindS = row["kind"]?.text, let kind = OutboxOpKind(rawValue: kindS),
                  let table = row["table_name"]?.text,
                  let idS = row["entity_id"]?.text, let uuid = UUID(uuidString: idS),
                  let payload = row["payload"]?.blob,
                  let upS = row["updated_at"]?.text, let up = iso.date(from: upS),
                  let attempts = row["attempts"]?.int else { return nil }
            return OutboxOp(seq: seq, kind: kind, tableName: table, entityId: uuid,
                            payload: payload, updatedAt: up, attempts: attempts,
                            lastError: row["last_error"]?.text)
        }
    }

    func deleteOp(seq: Int) throws { try db.execute("DELETE FROM outbox WHERE seq=?", [seq]) }

    func recordOpFailure(seq: Int, error: String) throws {
        try db.execute("UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE seq = ?", [error, seq])
    }

    // MARK: Sync cursor

    func cursor(for table: String) throws -> Date? {
        guard let s = try db.query("SELECT cursor FROM sync_cursor WHERE table_name=?", [table])
            .first?["cursor"]?.text else { return nil }
        return iso.date(from: s)
    }

    func setCursor(_ date: Date, for table: String) throws {
        try db.execute("""
            INSERT INTO sync_cursor (table_name, cursor) VALUES (?, ?)
            ON CONFLICT(table_name) DO UPDATE SET cursor=excluded.cursor;
            """, [table, iso.string(from: date)])
    }

    // MARK: Helpers

    private static func appendOp(_ conn: SQLiteDatabase.Connection, kind: OutboxOpKind,
                                 table: String, id: UUID, payload: Data, updatedAt: Date,
                                 iso: ISO8601DateFormatter) throws {
        // Coalesce: drop any existing pending op for this entity, keep only the latest.
        try conn.execute("DELETE FROM outbox WHERE table_name=? AND entity_id=?", [table, id.uuidString])
        try conn.execute("""
            INSERT INTO outbox (kind, table_name, entity_id, payload, updated_at)
            VALUES (?, ?, ?, ?, ?);
            """, [kind.rawValue, table, id.uuidString, payload, iso.string(from: updatedAt)])
    }
}
```

> Note: `ISO8601DateFormatter` default omits fractional seconds. Keep it consistent on both ends (LocalStore uses it for the `updated_at`/`deleted_at` *columns* only; entity payloads use the JSON `.iso8601` strategy). Column timestamps are used solely for ordering/cursor comparison, so second-resolution is acceptable.

- [ ] **Step 4: Run tests**

Run suite `LocalStore`. Expected: PASS (upsert/fetch, tombstone exclusion, atomic enqueue).

- [ ] **Step 5: Commit**

```bash
git add Home/Shared/Persistence/LocalStore.swift HomeTests/Persistence/LocalStoreTests.swift
git commit -m "feat: LocalStore SQLite entity CRUD, outbox, and sync cursor"
```

---

## Task 6: Outbox coalescing + failure bookkeeping tests

**Files:**
- Test: `HomeTests/Persistence/OutboxTests.swift`

No new production code — this hardens behavior already implemented in Task 5 (coalescing, attempts).

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run tests**

Run suite `Outbox behavior`. Expected: PASS (already supported by Task 5 impl).

> If `coalesce` fails, confirm `appendOp` deletes prior ops for the same `(table, entity_id)` before inserting.

- [ ] **Step 3: Commit**

```bash
git add HomeTests/Persistence/OutboxTests.swift
git commit -m "test: outbox coalescing and failure bookkeeping"
```

---

## Task 7: `Reachability`

**Files:**
- Create: `Home/Shared/Sync/Reachability.swift`

`NWPathMonitor` callbacks are not MainActor; bridge to an `AsyncStream<Bool>` and a `@MainActor` published flag. No unit test (depends on real network interface); covered manually.

- [ ] **Step 1: Implement**

```swift
// Home/Shared/Sync/Reachability.swift
import Foundation
import Network
import Observation

@MainActor
@Observable
final class Reachability {
    private(set) var isOnline: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "reachability.monitor")

    /// Emits `true`/`false` on each connectivity change. First value is the current state.
    let changes: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        var cont: AsyncStream<Bool>.Continuation!
        changes = AsyncStream { cont = $0 }
        continuation = cont
        monitor.pathUpdateHandler = { [continuation] path in
            let online = path.status == .satisfied
            continuation.yield(online)
            Task { @MainActor in
                // updated on main for UI observation
                NotificationCenter.default.post(name: .init("reachabilityChanged"),
                                                object: nil, userInfo: ["online": online])
            }
        }
        monitor.start(queue: queue)
        NotificationCenter.default.addObserver(forName: .init("reachabilityChanged"),
                                               object: nil, queue: .main) { [weak self] note in
            guard let online = note.userInfo?["online"] as? Bool else { return }
            MainActor.assumeIsolated { self?.isOnline = online }
        }
    }

    deinit { monitor.cancel(); continuation.finish() }
}
```

> If the `NotificationCenter` bridge feels heavy, an acceptable alternative is to drop the `@Observable isOnline` UI flag for v1 and expose only the `AsyncStream`; SyncEngine only needs the stream. Keep whichever compiles cleanest under Swift 6 — the SyncEngine contract is just "give me a stream of online booleans."

- [ ] **Step 2: Build**

Xcode `Cmd+B`. Expected: zero errors, zero concurrency warnings.

- [ ] **Step 3: Commit**

```bash
git add Home/Shared/Sync/Reachability.swift
git commit -m "feat: Reachability network monitor with AsyncStream"
```

---

## Task 8: `RemoteGateway` protocol + `SupabaseGateway`

**Files:**
- Create: `Home/Shared/Sync/RemoteGateway.swift`

Isolates Supabase so SyncEngine is testable with a fake.

- [ ] **Step 1: Implement**

```swift
// Home/Shared/Sync/RemoteGateway.swift
import Foundation
import Supabase

/// Network boundary for sync. One method per outbox op kind + a pull.
protocol RemoteGateway: Sendable {
    /// Push a single entity payload. insert/update both upsert; delete writes the
    /// tombstone (payload already carries deleted_at). Returns on success, throws on failure.
    func push(kind: OutboxOpKind, table: String, payload: Data) async throws
    /// Pull rows in `table` whose updated_at > `since` (nil = full). Returns raw JSON blobs.
    func pull(table: String, since: Date?) async throws -> [Data]
}

struct SupabaseGateway: RemoteGateway {
    let client: SupabaseClient
    private let iso = ISO8601DateFormatter()

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        // Upsert covers insert, update, and tombstone-delete uniformly (LWW server-side via updated_at).
        let json = try JSONSerialization.jsonObject(with: payload)
        guard let dict = json as? [String: Any] else { return }
        let coded = try AnyJSON(dict)            // Supabase SDK JSON type
        try await client.from(table).upsert(coded, onConflict: "id").execute()
    }

    func pull(table: String, since: Date?) async throws -> [Data] {
        var query = client.from(table).select()
        if let since { query = query.gt("updated_at", value: iso.string(from: since)) }
        let response = try await query.execute()
        // response.data is the raw JSON array; split into per-row blobs.
        let array = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []
        return try array.map { try JSONSerialization.data(withJSONObject: $0) }
    }
}
```

> Verify the exact Supabase SDK upsert signature in the pinned version (`AnyJSON` construction and `onConflict:` label). If `AnyJSON(dict)` is unavailable, decode `payload` into the concrete `Encodable` model per table via a small switch, or upsert the `Data` through the SDK’s JSON encoder. The contract (idempotent upsert keyed on `id`) must hold either way.

- [ ] **Step 2: Build**

Xcode `Cmd+B`. Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add Home/Shared/Sync/RemoteGateway.swift
git commit -m "feat: RemoteGateway protocol and Supabase implementation"
```

---

## Task 9: `SyncEngine` — push (drain outbox)

**Files:**
- Create: `Home/Shared/Sync/SyncEngine.swift`
- Test: `HomeTests/Sync/SyncEnginePushTests.swift`

- [ ] **Step 1: Write the failing test (with a fake gateway)**

```swift
import Testing
import Foundation
@testable import Home

actor FakeGateway: RemoteGateway {
    var pushed: [(OutboxOpKind, String)] = []
    var failTables: Set<String> = []
    var pullReturns: [String: [Data]] = [:]

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        if failTables.contains(table) { throw NSError(domain: "net", code: 1) }
        pushed.append((kind, table))
    }
    func pull(table: String, since: Date?) async throws -> [Data] { pullReturns[table] ?? [] }
    func setFail(_ t: String) { failTables.insert(t) }
    func pushedCount() -> Int { pushed.count }
}

@Suite("SyncEngine push") struct SyncEnginePushTests {
    private func make() async throws -> (SyncEngine, LocalStore, FakeGateway) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("se-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gw = FakeGateway()
        return (SyncEngine(local: store, gateway: gw), store, gw)
    }
    private func product() -> StockProduct {
        StockProduct(name: "Milk", icon: "i", packages: 1, looseUnits: 0, unitsPerPackage: 6)
    }

    @Test("successful push clears the outbox op")
    func pushClears() async throws {
        let (engine, store, gw) = try await make()
        try await store.upsert([product()], enqueue: true)
        try await engine.push()
        #expect(await gw.pushedCount() == 1)
        #expect(try await store.pendingOps().isEmpty)
    }

    @Test("failed push retains op and records error")
    func pushFails() async throws {
        let (engine, store, gw) = try await make()
        await gw.setFail("stock_products")
        try await store.upsert([product()], enqueue: true)
        try await engine.push()
        let ops = try await store.pendingOps()
        #expect(ops.count == 1)
        #expect(ops[0].attempts == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run suite `SyncEngine push`. Expected: FAIL — `SyncEngine` undefined.

- [ ] **Step 3: Implement SyncEngine (push only for now)**

```swift
// Home/Shared/Sync/SyncEngine.swift
import Foundation

/// Orchestrates push (drain outbox) and pull (reconcile) between LocalStore and Supabase.
actor SyncEngine {
    private let local: LocalStore
    private let gateway: any RemoteGateway
    private var isSyncing = false

    init(local: LocalStore, gateway: any RemoteGateway) {
        self.local = local
        self.gateway = gateway
    }

    /// Push then pull. Single-flight: overlapping calls are ignored.
    func sync(tables: [String]) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        try? await push()
        for table in tables { try? await pull(table: table) }
    }

    /// Drain the outbox in order. Each op: push to gateway; on success delete it,
    /// on failure record the error and continue (op stays for next sync).
    func push() async throws {
        for op in try await local.pendingOps() {
            do {
                try await gateway.push(kind: op.kind, table: op.tableName, payload: op.payload)
                try await local.deleteOp(seq: op.seq)
            } catch {
                try await local.recordOpFailure(seq: op.seq, error: error.localizedDescription)
            }
        }
    }

    // pull(table:) is added in Task 10.
}
```

- [ ] **Step 4: Run tests**

Run suite `SyncEngine push`. Expected: FAIL — `pull` not defined yet. Temporarily stub `func pull(table: String) async throws {}` so the suite compiles, then expect PASS for the two push tests. (Task 10 replaces the stub.)

- [ ] **Step 5: Commit**

```bash
git add Home/Shared/Sync/SyncEngine.swift HomeTests/Sync/SyncEnginePushTests.swift
git commit -m "feat: SyncEngine outbox push with retry bookkeeping"
```

---

## Task 10: `SyncEngine` — pull + reconcile (LWW)

**Files:**
- Modify: `Home/Shared/Sync/SyncEngine.swift`
- Test: `HomeTests/Sync/SyncEnginePullTests.swift`

Reconcile rule: for each pulled row, if no local row OR remote `updated_at >= local updated_at`, upsert it locally **without enqueueing** (it came from the server). Tombstones (`deleted_at != nil`) are upserted too — `fetchAll` already hides them. Advance the cursor to the max `updated_at` seen.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Home

@Suite("SyncEngine pull") struct SyncEnginePullTests {
    private func make() async throws -> (SyncEngine, LocalStore, FakeGateway) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sp-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gw = FakeGateway()
        return (SyncEngine(local: store, gateway: gw), store, gw)
    }
    private func blob(id: UUID, name: String, updatedAt: Date, deletedAt: Date? = nil) throws -> Data {
        let p = StockProduct(id: id, name: name, icon: "i", packages: 1, looseUnits: 0,
                             unitsPerPackage: 6, updatedAt: updatedAt, deletedAt: deletedAt)
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        return try e.encode(p)
    }

    @Test("pull inserts a new remote row locally without enqueueing")
    func pullInserts() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        await gw.setPull("stock_products", [try blob(id: id, name: "Milk", updatedAt: .now)])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Milk"])
        #expect(try await store.pendingOps().isEmpty)
    }

    @Test("newer local wins over older remote (LWW)")
    func localWins() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        let newer = StockProduct(id: id, name: "Local", icon: "i", packages: 1, looseUnits: 0,
                                 unitsPerPackage: 6, updatedAt: .now)
        try await store.upsert([newer], enqueue: false)
        await gw.setPull("stock_products",
                         [try blob(id: id, name: "Remote", updatedAt: .now.addingTimeInterval(-60))])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Local"])
    }

    @Test("remote tombstone hides the row")
    func remoteTombstone() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        try await store.upsert([StockProduct(id: id, name: "Milk", icon: "i", packages: 1,
                                             looseUnits: 0, unitsPerPackage: 6)], enqueue: false)
        await gw.setPull("stock_products",
                         [try blob(id: id, name: "Milk", updatedAt: .now.addingTimeInterval(60),
                                   deletedAt: .now.addingTimeInterval(60))])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).isEmpty)
    }
}
```

Add this helper to `FakeGateway` (Task 9 file):

```swift
    func setPull(_ t: String, _ data: [Data]) { pullReturns[t] = data }
```

- [ ] **Step 2: Run test to verify it fails**

Run suite `SyncEngine pull`. Expected: FAIL — `pull(table:)` is a no-op stub.

- [ ] **Step 3: Implement pull + reconcile generically**

Replace the `pull` stub. Because reconcile needs the concrete type to decode, dispatch by table name through a registry. Add to `SyncEngine`:

```swift
    /// All synced tables in dependency order (parents before children).
    static let syncedTables: [String] = [
        "pets", "veterinarian", "appointments", "clinical_entries", "pet_events",
        "task_sections", "household_tasks", "stock_products", "meals", "meal_products"
    ]

    func pull(table: String) async throws {
        let since = try await local.cursor(for: table)
        let blobs = try await gateway.pull(table: table, since: since)
        guard !blobs.isEmpty else { return }
        let maxUpdated = try await reconcile(table: table, blobs: blobs)
        if let maxUpdated { try await local.setCursor(maxUpdated, for: table) }
    }

    /// Decode + LWW-upsert each blob. Returns the max updatedAt across the batch.
    private func reconcile(table: String, blobs: [Data]) async throws -> Date? {
        switch table {
        case "pets":            return try await reconcileTyped(Pet.self, blobs)
        case "veterinarian":    return try await reconcileTyped(Veterinarian.self, blobs)
        case "appointments":    return try await reconcileTyped(Appointment.self, blobs)
        case "clinical_entries":return try await reconcileTyped(ClinicalEntry.self, blobs)
        case "pet_events":      return try await reconcileTyped(PetEvent.self, blobs)
        case "task_sections":   return try await reconcileTyped(TaskSection.self, blobs)
        case "household_tasks": return try await reconcileTyped(HouseholdTask.self, blobs)
        case "stock_products":  return try await reconcileTyped(StockProduct.self, blobs)
        case "meals":           return try await reconcileTyped(Meal.self, blobs)
        case "meal_products":   return try await reconcileTyped(MealProduct.self, blobs)
        default: return nil
        }
    }

    private func reconcileTyped<T: SyncableEntity>(_ type: T.Type, _ blobs: [Data]) async throws -> Date? {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var maxUpdated: Date?
        let localById = try await local.indexByID(T.self)   // [UUID: Date] of local updatedAt
        var toUpsert: [T] = []
        for blob in blobs {
            let remote = try decoder.decode(T.self, from: blob)
            maxUpdated = max(maxUpdated ?? remote.updatedAt, remote.updatedAt)
            if let localUpdated = localById[remote.id], localUpdated > remote.updatedAt { continue } // local newer
            toUpsert.append(remote)
        }
        if !toUpsert.isEmpty { try await local.upsert(toUpsert, enqueue: false) }
        return maxUpdated
    }
```

> The gateway decodes Supabase JSON (snake_case) — but `reconcileTyped` decodes with a plain `.iso8601` JSONDecoder. The blobs from `SupabaseGateway.pull` are raw Supabase rows (snake_case keys). Models already declare snake_case `CodingKeys`, so this decodes correctly. In tests, `blob(...)` encodes with the same `CodingKeys`, so keys match. Confirm date format: Supabase returns RFC3339 with offset; if `.iso8601` decode fails on fractional seconds, set `decoder.dateDecodingStrategy = .custom` with a formatter accepting fractional seconds. Add that fallback if any pull test fails on dates.

Add the helper to `LocalStore`:

```swift
    /// Map of id -> updatedAt for all rows (incl. tombstoned) of a table — for LWW comparison.
    func indexByID<T: SyncableEntity>(_ type: T.Type) throws -> [UUID: Date] {
        let rows = try db.query("SELECT id, updated_at FROM entities WHERE table_name=?", [T.tableName])
        var map: [UUID: Date] = [:]
        for row in rows {
            guard let idS = row["id"]?.text, let id = UUID(uuidString: idS),
                  let upS = row["updated_at"]?.text, let up = iso.date(from: upS) else { continue }
            map[id] = up
        }
        return map
    }
```

Remove the temporary `pull` stub added in Task 9.

- [ ] **Step 4: Run tests**

Run suites `SyncEngine pull` + `SyncEngine push`. Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add Home/Shared/Sync/SyncEngine.swift Home/Shared/Persistence/LocalStore.swift HomeTests/Sync/SyncEnginePullTests.swift HomeTests/Sync/SyncEnginePushTests.swift
git commit -m "feat: SyncEngine pull and last-write-wins reconciliation"
```

---

## Task 11: Supabase migration — `updated_at` / `deleted_at` on all 9 tables

**Files:**
- Create: `supabase/migrations/20260616120000_offline_sync_columns.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Offline-first sync: updated_at + deleted_at on all synced tables.
do $$
declare t text;
begin
  foreach t in array array[
    'pets','veterinarian','appointments','clinical_entries','pet_events',
    'task_sections','household_tasks','stock_products','meals','meal_products'
  ] loop
    execute format('alter table %I add column if not exists updated_at timestamptz not null default now()', t);
    execute format('alter table %I add column if not exists deleted_at timestamptz', t);
    execute format('create index if not exists %I on %I (updated_at)', t || '_updated_at_idx', t);
  end loop;
end $$;

-- Auto-bump updated_at on every update.
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

do $$
declare t text;
begin
  foreach t in array array[
    'pets','veterinarian','appointments','clinical_entries','pet_events',
    'task_sections','household_tasks','stock_products','meals','meal_products'
  ] loop
    execute format('drop trigger if exists %I on %I', t || '_set_updated_at', t);
    execute format('create trigger %I before update on %I for each row execute function set_updated_at()',
                   t || '_set_updated_at', t);
  end loop;
end $$;
```

> RLS: existing policies (migration `20260531200000_enable_rls.sql`) must still allow `select` of rows where `deleted_at is not null` (so tombstones sync) and `update` of `deleted_at`. If policies filter on row ownership only, no change needed. **Read that file and confirm** no policy hard-excludes soft-deleted rows; if one does, widen it.

- [ ] **Step 2: Apply the migration**

Run: `supabase db push`
Expected: migration applies cleanly; `\d stock_products` shows `updated_at`, `deleted_at`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260616120000_offline_sync_columns.sql
git commit -m "feat: add updated_at/deleted_at sync columns to all synced tables"
```

---

## Task 12: Rewire `SupabaseStore` to the local-first facade

**Files:**
- Modify: `Home/Shared/Services/SupabaseStore.swift`
- Modify: `Home/ContentView.swift`

This is the integration task. `SupabaseStore` keeps its public API and arrays, but:
- builds a `LocalStore` + `SyncEngine` + `Reachability` in `init`,
- `loadAll()` hydrates arrays from `LocalStore` (offline-instant), then kicks `sync()`,
- mutations write LocalStore (optimistic + outbox) then update arrays,
- a connectivity task triggers `sync()` on reconnect.

- [ ] **Step 1: Add infrastructure to `SupabaseStore.init` and a hydrate method**

```swift
    let local: LocalStore
    let sync: SyncEngine
    let reachability = Reachability()
    private var reconnectTask: Task<Void, Never>?

    init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )
        let dbURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.guille.Home")?
            .appendingPathComponent("home.sqlite")
            ?? URL.documentsDirectory.appendingPathComponent("home.sqlite")
        // LocalStore init is async; build it lazily on first loadAll instead (see below).
        self.localURL = dbURL
    }
```

> Because `LocalStore.init` is `async` and `SupabaseStore.init` is sync, store the URL and create `LocalStore`/`SyncEngine` at the top of `loadAll()`. Make `local`/`sync` optionals or use an `async` factory. Recommended shape: a private `var localURL: URL` plus `private var _local: LocalStore?` / `_sync: SyncEngine?` created once in `loadAll()`. Keep them non-optional accessors that `fatalError` if used before load, OR convert `SupabaseStore` creation to an async factory called from ContentView. Choose the optional-with-lazy-init approach to minimize call-site churn.

- [ ] **Step 2: Replace `loadAll()` with hydrate-then-sync**

```swift
    func loadAll() async {
        isLoading = true
        loadError = nil
        do {
            if _local == nil {
                let store = try await LocalStore(url: localURL)
                _local = store
                _sync = SyncEngine(local: store, gateway: SupabaseGateway(client: client))
                startReconnectObserver()
            }
            try await hydrate()              // arrays from local cache (works offline)
            isLoading = false
            await _sync?.sync(tables: SyncEngine.syncedTables)   // background reconcile
            try? await hydrate()             // refresh arrays after pull
            WidgetSnapshotWriter.write(from: self)
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    private func hydrate() async throws {
        guard let local = _local else { return }
        pets            = try await local.fetchAll(Pet.self)
        veterinarians   = try await local.fetchAll(Veterinarian.self)
        appointments    = try await local.fetchAll(Appointment.self)
        clinicalEntries = try await local.fetchAll(ClinicalEntry.self)
        events          = try await local.fetchAll(PetEvent.self)
        householdTasks  = try await local.fetchAll(HouseholdTask.self)
        customSections  = try await local.fetchAll(TaskSection.self)
        stockProducts   = try await local.fetchAll(StockProduct.self)
        meals           = try await local.fetchAll(Meal.self)
        mealProducts    = try await local.fetchAll(MealProduct.self)
    }

    private func startReconnectObserver() {
        reconnectTask = Task { [weak self] in
            guard let stream = self?.reachability.changes else { return }
            for await online in stream where online {
                await self?._sync?.sync(tables: SyncEngine.syncedTables)
                try? await self?.hydrate()
            }
        }
    }
```

> First-run cold start with an empty local DB: the initial `sync()` performs a full pull (cursor nil → all rows), populating LocalStore; the post-sync `hydrate()` fills the arrays. Offline first-ever launch shows empty data — acceptable.

- [ ] **Step 3: Convert each mutation to optimistic local-first (worked example: `addProduct`)**

```swift
    func addProduct(_ product: StockProduct) async throws {
        var p = product
        p.updatedAt = .now
        try await _local?.upsert([p], enqueue: true)   // local + outbox, atomic
        stockProducts.append(p)
        await _sync?.sync(tables: ["stock_products"])   // attempt immediate push
    }

    func updateProduct(_ product: StockProduct) async throws {
        var p = product
        p.updatedAt = .now
        try await _local?.upsert([p], enqueue: true)
        if let i = stockProducts.firstIndex(where: { $0.id == p.id }) { stockProducts[i] = p }
        await _sync?.sync(tables: ["stock_products"])
    }

    func deleteProduct(_ product: StockProduct) async throws {
        try await _local?.softDelete(product, enqueue: true)
        stockProducts.removeAll { $0.id == product.id }
        for i in householdTasks.indices where householdTasks[i].productId == product.id {
            householdTasks[i].productId = nil
            try await _local?.upsert([householdTasks[i]], enqueue: true)
        }
        await _sync?.sync(tables: ["stock_products", "household_tasks"])
    }
```

- [ ] **Step 4: Apply the same transformation to every remaining mutation**

For each existing `add*/update*/delete*` method (`addPet`, `updatePet`, `deletePet`, `addVet`, `updateVet`, `deleteVet`, `addAppointment`, `updateAppointmentStatus`, `deleteAppointment`, `addClinicalEntry`, `deleteClinicalEntry`, `addEvent`, `deleteEvent`, `addTask`, `updateTask`, `deleteTask`, `addCustomSection`, `deleteCustomSection`, `replenish`, `completeTask`, and `SupabaseStore+Meals.swift` mutations):
1. Set `updatedAt = .now` on the entity.
2. Replace `try await client.from(...)...execute()` with `try await _local?.upsert([entity], enqueue: true)` (or `softDelete(entity, enqueue: true)` for deletes).
3. Keep the existing in-memory array update line.
4. Append `await _sync?.sync(tables: [<affected tables>])`.
5. For cascading deletes (e.g. `deletePet` clearing appointments/events), soft-delete each child entity locally too (so the cascade syncs).

> **File operations stay online-only.** `uploadFile`, `updatePetPhoto`, `deleteFile`, `analyzeFile` keep calling `client.storage`/`functions` directly. Wrap their bodies so that when `reachability.isOnline == false` they throw a clear error:
> ```swift
> guard reachability.isOnline else { throw SyncError.requiresConnection }
> ```
> Define `enum SyncError: LocalizedError { case requiresConnection; var errorDescription: String? { "This action needs an internet connection." } }` in `Home/Shared/Sync/SyncEngine.swift`.

- [ ] **Step 5: Update `ContentView` loading gate (don’t block on network)**

In `Home/ContentView.swift`, the `loadError` branch currently blocks the whole UI on a connection error. After this change `loadAll()` only sets `loadError` for genuine local failures (DB open errors), not network — network failures are silent and retried. Keep the existing structure; just confirm the `Retry` button still calls `Task { await store.loadAll() }`. Optionally add an offline banner driven by `store.reachability.isOnline`. Minimal required change: none if `loadError` stays nil on network failure (it does — sync swallows network errors). Verify by reading the new `loadAll()`.

- [ ] **Step 6: Build**

Xcode `Cmd+B`. Expected: zero errors, zero Swift 6 concurrency warnings.

- [ ] **Step 7: Run the full test suite**

Run all `HomeTests` (`Cmd+U`). Expected: all PASS. Existing `SupabaseStoreTests`/filter/meal tests that exercise in-memory array logic still hold (array updates unchanged). If any test calls a mutation and asserts on arrays, it passes because arrays are still updated; the local/outbox writes are additive.

> If existing tests construct `SupabaseStore()` and call mutations expecting them not to hit a network, they now hit `_local` (nil until `loadAll`). Guard mutations with `_local?` (optional) so they no-op the persistence side when not loaded, OR update those tests to `await loadAll()` first against a temp DB. Prefer the optional-chaining no-op to avoid touching tests.

- [ ] **Step 8: Commit**

```bash
git add Home/Shared/Services/SupabaseStore.swift Home/Shared/Services/SupabaseStore+Meals.swift Home/ContentView.swift Home/Shared/Sync/SyncEngine.swift
git commit -m "feat: local-first SupabaseStore facade with optimistic mutations and reconnect sync"
```

---

## Task 13: Widget App Group entitlement finish + verify offline widget data

**Files:**
- Modify: `Home/Home.entitlements`, `HomeWidget/HomeWidget.entitlements` (App Group `group.com.guille.Home`)
- Already staged partial entitlement work — complete it.

- [ ] **Step 1: Ensure both targets share the App Group**

Both `.entitlements` files must contain:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.guille.Home</string>
</array>
```

Confirm in Xcode → each target → Signing & Capabilities → App Groups shows `group.com.guille.Home` checked.

- [ ] **Step 2: Build + run on simulator**

Xcode `Cmd+R`. Let `loadAll()` hydrate + sync. Background the app (so `WidgetSnapshotWriter.write` runs) and confirm the widget shows real events/meals/stock (not placeholder).

- [ ] **Step 3: Verify offline path (manual)**

1. With data loaded, enable Airplane Mode in the simulator’s host or toggle network off.
2. Edit stock (e.g. consume a unit). UI updates immediately.
3. Force-quit + relaunch: data still present (hydrated from LocalStore).
4. Re-enable network. Confirm the change reaches Supabase (check the dashboard / a second device) and `pendingOps()` drains (add a temporary debug log if needed, then remove).

- [ ] **Step 4: Commit**

```bash
git add Home/Home.entitlements HomeWidget/HomeWidget.entitlements Home.xcodeproj/project.pbxproj
git commit -m "feat: share App Group so widget reads local-backed snapshot offline"
```

---

## Self-Review (completed during authoring)

**Spec coverage:**
- LocalStore SQLite source of truth → Tasks 3, 5. ✔
- SupabaseStore facade hydrate → Task 12. ✔
- Optimistic transactional mutations (row + outbox in one txn) → Task 5 (`upsert enqueue`), Task 12. ✔
- SyncEngine push/pull + NWPathMonitor + LWW → Tasks 7, 9, 10, 12. ✔
- Soft-delete tombstones + delete sync → Tasks 5 (`softDelete`), 10 (tombstone reconcile), 11 (`deleted_at`). ✔
- Migration: updated_at/deleted_at + index + trigger → Task 11. ✔
- Files stay online-only with offline error → Task 12 Step 4. ✔
- Outbox coalescing + retry/backoff bookkeeping → Tasks 5, 6, 9. ✔
- Widget reads local-backed data offline → Task 13. ✔
- Error handling (offline silent, push retry, pull abort) → Tasks 9, 12. ✔

**Placeholder scan:** No "TBD"/"implement later". Where the SDK signature is version-dependent (Task 8 upsert, Task 10 date decoding) the plan states the exact contract and the concrete fallback. Model edits (Task 2) are enumerated per file with identical, fully-specified changes.

**Type consistency:** `LocalStore` API (`upsert(_:enqueue:)`, `softDelete(_:enqueue:)`, `fetchAll(_:)`, `pendingOps()`, `deleteOp(seq:)`, `recordOpFailure(seq:error:)`, `cursor(for:)`, `setCursor(_:for:)`, `indexByID(_:)`) is used identically across Tasks 5, 6, 9, 10, 12. `RemoteGateway.push(kind:table:payload:)` / `pull(table:since:)` consistent across Tasks 8, 9, 10. `OutboxOp` fields consistent Tasks 4, 5, 9. `SyncEngine.sync(tables:)` / `push()` / `pull(table:)` / `syncedTables` consistent Tasks 9, 10, 12.

**Known risk flagged for executor:** Swift 6 strict concurrency around `SQLiteDatabase.Connection` (a class passed into the `transaction` closure) — it stays inside the actor, never escapes, so it does not need to be `Sendable`. If the compiler complains, mark the closure `@Sendable`-free by keeping `transaction` non-`async` (it is) and the `Connection` non-escaping.
