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

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        let object = try JSONDecoder().decode(JSONObject.self, from: payload)
        try await client.from(table).upsert(object, onConflict: "id").execute()
    }

    func pull(table: String, since: Date?) async throws -> [Data] {
        var query = client.from(table).select()
        if let since {
            let iso = ISO8601DateFormatter()
            query = query.gt("updated_at", value: iso.string(from: since))
        }
        let response = try await query.execute()
        let array = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []
        return try array.map { try JSONSerialization.data(withJSONObject: $0) }
    }
}
