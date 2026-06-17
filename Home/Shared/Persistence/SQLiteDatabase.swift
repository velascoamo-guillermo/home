import Foundation
import SQLite3

/// A bound SQLite value (the subset we store).
enum SQLValue: Sendable, Equatable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case null

    nonisolated var text: String?   { if case .text(let v)   = self { return v } else { return nil } }
    nonisolated var int: Int?       { if case .int(let v)    = self { return v } else { return nil } }
    nonisolated var double: Double? { if case .double(let v) = self { return v } else { return nil } }
    nonisolated var blob: Data?     { if case .blob(let v)   = self { return v } else { return nil } }
    nonisolated var isNull: Bool    { if case .null = self { return true } else { return false } }
}

/// Literals usable as bind parameters.
protocol SQLBindable: Sendable { nonisolated var sqlValue: SQLValue { get } }
extension String: SQLBindable { nonisolated var sqlValue: SQLValue { .text(self) } }
extension Int:    SQLBindable { nonisolated var sqlValue: SQLValue { .int(self) } }
extension Double: SQLBindable { nonisolated var sqlValue: SQLValue { .double(self) } }
extension Data:   SQLBindable { nonisolated var sqlValue: SQLValue { .blob(self) } }

enum SQLiteError: Error { case open(Int32), prepare(String), step(Int32, String) }

/// Serializes all access to a single sqlite3 handle. SQLite C types are not
/// Sendable; actor isolation keeps every call on one executor.
actor SQLiteDatabase {
    /// Synchronous connection facade passed into `transaction` closures.
    /// Only ever lives inside the actor's isolation — never escapes.
    // Only accessed through SQLiteDatabase's actor isolation — never stored or called outside a transaction body running on the actor.
    final class Connection: @unchecked Sendable {
        fileprivate let handle: OpaquePointer
        fileprivate init(_ h: OpaquePointer) { handle = h }

        func execute(_ sql: String, _ params: [SQLBindable?] = []) throws {
            let stmt = try prepare(sql, params)
            defer { sqlite3_finalize(stmt) }
            let rc = sqlite3_step(stmt)
            guard rc == SQLITE_DONE else {
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
                        } else { row[name] = .null }
                    default: row[name] = .null
                    }
                }
                out.append(row)
            }
            return out
        }

        private func prepare(_ sql: String, _ params: [SQLBindable?]) throws -> OpaquePointer {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
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
                case .blob(let v):   _ = v.withUnsafeBytes { sqlite3_bind_blob(stmt, pos, $0.baseAddress, Int32(v.count), SQLITE_TRANSIENT) }
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

    func transaction<T>(_ body: (Connection) throws -> T) throws -> T {
        try conn.execute("BEGIN")
        do {
            let result = try body(conn)
            try conn.execute("COMMIT")
            return result
        } catch let commitError {
            do {
                try conn.execute("ROLLBACK")
            } catch {
                throw error  // ROLLBACK failed — unrecoverable
            }
            throw commitError
        }
    }

    func userVersion() throws -> Int {
        try query("PRAGMA user_version", []).first?["user_version"]?.int ?? 0
    }

    func setUserVersion(_ v: Int) throws {
        try execute("PRAGMA user_version = \(v)")
    }
}
