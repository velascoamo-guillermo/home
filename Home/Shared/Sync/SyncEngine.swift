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

    /// Stub — replaced in Task 10.
    func pull(table: String) async throws {}
}
