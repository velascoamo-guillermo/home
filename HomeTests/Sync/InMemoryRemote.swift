import Foundation
@testable import Casita

/// Mimics Supabase for sync tests: upsert merges only the keys present (PostgREST
/// semantics) and the server stamps updated_at on every write (set_updated_at trigger).
actor InMemoryRemote: RemoteGateway {
    private var tables: [String: [String: (payload: Data, stampedAt: Date)]] = [:]
    private var clock = Date(timeIntervalSinceNow: 60)
    private var failPulls = false

    func setFailPulls(_ fail: Bool) { failPulls = fail }

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        guard let incoming = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let rawId = incoming["id"] as? String else { throw URLError(.cannotParseResponse) }
        let id = rawId.lowercased()
        var merged: [String: Any] = [:]
        if let existing = tables[table]?[id],
           let old = try JSONSerialization.jsonObject(with: existing.payload) as? [String: Any] {
            merged = old
        }
        for (key, value) in incoming { merged[key] = value }
        clock = clock.addingTimeInterval(1)
        merged["updated_at"] = ISO8601DateFormatter().string(from: clock)
        tables[table, default: [:]][id] = (try JSONSerialization.data(withJSONObject: merged), clock)
    }

    func pull(table: String, since: Date?) async throws -> [Data] {
        if failPulls { throw URLError(.notConnectedToInternet) }
        return (tables[table] ?? [:]).values
            .filter { row in since.map { row.stampedAt > $0 } ?? true }
            .sorted { $0.stampedAt < $1.stampedAt }
            .map(\.payload)
    }

    func rowCount(_ table: String) -> Int { tables[table]?.count ?? 0 }

    /// True when the row exists and its deleted_at is JSON null. Returns a Bool rather
    /// than the row so nothing non-Sendable crosses the actor boundary.
    func deletedAtIsNull(_ table: String, id: UUID) -> Bool {
        guard let data = tables[table]?[id.uuidString.lowercased()]?.payload,
              let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return row["deleted_at"] is NSNull
    }
}
