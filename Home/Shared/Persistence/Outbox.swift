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
