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
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = SyncDateCoding.makeDecoder()
        try await Self.migrate(db)
    }

    private static func migrate(_ db: SQLiteDatabase) async throws {
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS entities (
              table_name TEXT NOT NULL, id TEXT NOT NULL,
              updated_at TEXT NOT NULL, deleted_at TEXT,
              payload BLOB NOT NULL, PRIMARY KEY (table_name, id));
            """)
        try await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_entities_sync ON entities(table_name, updated_at)"
        )
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
    func upsert<T: SyncableEntity>(_ items: [T], enqueue: Bool) async throws {
        let rows = try items.map { item -> (T, Data, String, String?) in
            (item, try encoder.encode(item),
             iso.string(from: item.updatedAt),
             item.deletedAt.map { iso.string(from: $0) })
        }
        try await db.transaction { conn in
            for (item, blob, updatedAtS, deletedAtS) in rows {
                try conn.execute("""
                    INSERT INTO entities (table_name, id, updated_at, deleted_at, payload)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(table_name, id) DO UPDATE SET
                      updated_at=excluded.updated_at, deleted_at=excluded.deleted_at, payload=excluded.payload;
                    """, [T.tableName, item.id.uuidString, updatedAtS, deletedAtS, blob])
                if enqueue {
                    try Self.appendOp(conn, kind: .update, table: T.tableName,
                                      id: item.id, payload: blob, updatedAtS: updatedAtS)
                }
            }
        }
    }

    /// Tombstone an entity (sets deleted_at = now, bumps updated_at). Optionally enqueues a delete op.
    func softDelete<T: SyncableEntity>(_ item: T, enqueue: Bool, now: Date = .now) async throws {
        var tomb = item
        tomb.deletedAt = now
        tomb.updatedAt = now
        let blob = try encoder.encode(tomb)
        let tableName = T.tableName
        let idString = item.id.uuidString
        let itemId = item.id
        let nowS = iso.string(from: now)
        try await db.transaction { conn in
            try conn.execute("""
                UPDATE entities SET updated_at=?, deleted_at=?, payload=? WHERE table_name=? AND id=?;
                """, [nowS, nowS, blob, tableName, idString])
            if enqueue {
                try Self.appendOp(conn, kind: .delete, table: tableName,
                                  id: itemId, payload: blob, updatedAtS: nowS)
            }
        }
    }

    func fetchAll<T: SyncableEntity>(_ type: T.Type) async throws -> [T] {
        let rows = try await db.query("""
            SELECT payload FROM entities WHERE table_name=? AND deleted_at IS NULL ORDER BY updated_at DESC;
            """, [T.tableName])
        return try rows.compactMap { row in
            guard let blob = row["payload"]?.blob else { return nil }
            return try decoder.decode(T.self, from: blob)
        }
    }

    // MARK: Outbox

    func pendingOps() async throws -> [OutboxOp] {
        let rows = try await db.query("""
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

    func deleteOp(seq: Int) async throws {
        try await db.execute("DELETE FROM outbox WHERE seq=?", [seq])
    }

    func recordOpFailure(seq: Int, error: String) async throws {
        try await db.execute(
            "UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE seq = ?",
            [error, seq]
        )
    }

    // MARK: Sync cursor

    func cursor(for table: String) async throws -> Date? {
        guard let s = try await db.query(
            "SELECT cursor FROM sync_cursor WHERE table_name=?", [table]
        ).first?["cursor"]?.text else { return nil }
        return iso.date(from: s)
    }

    func setCursor(_ date: Date, for table: String) async throws {
        try await db.execute("""
            INSERT INTO sync_cursor (table_name, cursor) VALUES (?, ?)
            ON CONFLICT(table_name) DO UPDATE SET cursor=excluded.cursor;
            """, [table, iso.string(from: date)])
    }

    // MARK: LWW helper (used by SyncEngine Task 10)

    /// Map of id -> updatedAt for all rows (incl. tombstoned) of a table — for LWW comparison.
    func indexByID<T: SyncableEntity>(_ type: T.Type) async throws -> [UUID: Date] {
        let rows = try await db.query(
            "SELECT id, updated_at FROM entities WHERE table_name=?", [T.tableName]
        )
        var map: [UUID: Date] = [:]
        for row in rows {
            guard let idS = row["id"]?.text, let id = UUID(uuidString: idS),
                  let upS = row["updated_at"]?.text, let up = iso.date(from: upS) else { continue }
            map[id] = up
        }
        return map
    }

    // MARK: Private

    private static func appendOp(_ conn: SQLiteDatabase.Connection, kind: OutboxOpKind,
                                  table: String, id: UUID, payload: Data, updatedAtS: String) throws {
        // Coalesce: drop any existing pending op for this entity, keep only the latest.
        try conn.execute("DELETE FROM outbox WHERE table_name=? AND entity_id=?", [table, id.uuidString])
        try conn.execute("""
            INSERT INTO outbox (kind, table_name, entity_id, payload, updated_at)
            VALUES (?, ?, ?, ?, ?);
            """, [kind.rawValue, table, id.uuidString, payload, updatedAtS])
    }
}
