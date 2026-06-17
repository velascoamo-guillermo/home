import Foundation

enum SyncError: LocalizedError {
    case requiresConnection
    var errorDescription: String? { "This action requires an internet connection." }
}

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
    /// on failure record the error and continue.
    func push() async throws {
        for op in try await local.pendingOps() {
            do {
                try await gateway.push(kind: op.kind, table: op.tableName, payload: op.payload)
                try await local.deleteOp(seq: op.seq)
            } catch {
                try? await local.recordOpFailure(seq: op.seq, error: error.localizedDescription)
            }
        }
    }

    static let syncedTables: [String] = [
        Pet.tableName, Veterinarian.tableName, Appointment.tableName,
        ClinicalEntry.tableName, PetEvent.tableName, TaskSection.tableName,
        HouseholdTask.tableName, StockProduct.tableName, Meal.tableName,
        MealProduct.tableName
    ]

    func pull(table: String) async throws {
        let since = try await local.cursor(for: table)
        let blobs = try await gateway.pull(table: table, since: since)
        guard !blobs.isEmpty else { return }
        let maxUpdated = try await reconcile(table: table, blobs: blobs)
        if let maxUpdated { try await local.setCursor(maxUpdated, for: table) }
    }

    private func reconcile(table: String, blobs: [Data]) async throws -> Date? {
        switch table {
        case "pets":             return try await reconcileTyped(Pet.self, blobs)
        case "veterinarian":     return try await reconcileTyped(Veterinarian.self, blobs)
        case "appointments":     return try await reconcileTyped(Appointment.self, blobs)
        case "clinical_entries": return try await reconcileTyped(ClinicalEntry.self, blobs)
        case "pet_events":       return try await reconcileTyped(PetEvent.self, blobs)
        case "task_sections":    return try await reconcileTyped(TaskSection.self, blobs)
        case "household_tasks":  return try await reconcileTyped(HouseholdTask.self, blobs)
        case "stock_products":   return try await reconcileTyped(StockProduct.self, blobs)
        case "meals":            return try await reconcileTyped(Meal.self, blobs)
        case "meal_products":    return try await reconcileTyped(MealProduct.self, blobs)
        default:
            assertionFailure("reconcile: unhandled table '\(table)'")
            return nil
        }
    }

    private func reconcileTyped<T: SyncableEntity>(_ type: T.Type, _ blobs: [Data]) async throws -> Date? {
        let decoder = SyncDateCoding.makeDecoder()
        var maxUpdated: Date?
        let localById = try await local.indexByID(T.self)
        var toUpsert: [T] = []
        for blob in blobs {
            let remote = try decoder.decode(T.self, from: blob)
            maxUpdated = maxUpdated.map { max($0, remote.updatedAt) } ?? remote.updatedAt
            if let localUpdated = localById[remote.id], localUpdated > remote.updatedAt { continue }
            toUpsert.append(remote)
        }
        if !toUpsert.isEmpty { try await local.upsert(toUpsert, enqueue: false) }
        return maxUpdated
    }
}

/// Lenient ISO8601 decoding for sync. Postgres `timestamptz` emits fractional
/// seconds (e.g. `2024-06-01T12:00:00.123456+00:00`) which Foundation's
/// `.iso8601` strategy cannot parse — it throws, aborting reconcile for any
/// model without a tolerant custom decoder. This tries fractional first, then plain.
nonisolated enum SyncDateCoding {
    static func date(from string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = date(from: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Invalid ISO8601 date: \(raw)")
            }
            return date
        }
        return decoder
    }
}
