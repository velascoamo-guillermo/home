import Testing
import Foundation
@testable import Casita

actor FakeGateway: RemoteGateway {
    private var pushed: [(OutboxOpKind, String, Data)] = []
    private var failTables: Set<String> = []
    private var pullReturns: [String: [Data]] = [:]

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        if failTables.contains(table) { throw NSError(domain: "net", code: 1) }
        pushed.append((kind, table, payload))
    }
    private(set) var pullSinces: [Date?] = []
    func pull(table: String, since: Date?) async throws -> [Data] {
        pullSinces.append(since)
        return pullReturns[table] ?? []
    }
    func setFail(_ t: String) async { failTables.insert(t) }
    func pushedCount() async -> Int { pushed.count }
    func pushedPayloads() async -> [Data] { pushed.map(\.2) }
    func setPull(_ t: String, _ data: [Data]) async { pullReturns[t] = data }
}

@Suite("SyncEngine push") @MainActor struct SyncEnginePushTests {
    private func make() async throws -> (SyncEngine, LocalStore, FakeGateway) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("se-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gw = FakeGateway()
        return (SyncEngine(local: store, gateway: gw), store, gw)
    }
    private func product() -> StockProduct {
        StockProduct(name: "Milk", level: .full)
    }

    @Test("successful push clears the outbox op")
    func pushClears() async throws {
        let (engine, store, gw) = try await make()
        try await store.upsert([product()], enqueue: true)
        try await engine.push()
        let count = await gw.pushedCount()
        #expect(count == 1)
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

    private func pushedObject(_ gw: FakeGateway) async throws -> [String: Any] {
        let payloads = await gw.pushedPayloads()
        #expect(payloads.count == 1)
        let data = try #require(payloads.first)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("legacy task payload with an icon key is normalized to a section key")
    func normalizesLegacyTaskPayload() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        let updatedAtRaw = "2024-06-01T12:00:00+00:00"
        let updatedAt = try #require(SyncDateCoding.date(from: updatedAtRaw))
        let blob = Data("""
            {"id":"\(id.uuidString)","title":"Filter","icon":"drop",
             "interval_days":30,"next_due_date":"2024-05-01T09:00:00+00:00",
             "notes":"","quantity_per_completion":1,"updated_at":"\(updatedAtRaw)"}
            """.utf8)
        try await store.enqueueRaw(kind: .update, table: "household_tasks", id: id,
                                   payload: blob, updatedAt: updatedAt)

        try await engine.push()

        let obj = try await pushedObject(gw)
        #expect(obj["section"] as? String == "plumbing")
        #expect(obj["icon"] == nil)
        #expect(obj["id"] as? String == id.uuidString)
        #expect(obj["title"] as? String == "Filter")
        let pushedUpdatedAt = SyncDateCoding.date(from: (obj["updated_at"] as? String) ?? "")
        #expect(pushedUpdatedAt == updatedAt)
    }

    @Test("legacy stock payload gains a level from its units and drops icon and unit keys")
    func normalizesLegacyProductPayload() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        let blob = Data("""
            {"id":"\(id.uuidString)","name":"Milk","icon":"x","packages":0,
             "loose_units":3,"units_per_package":6,"needed":true,
             "created_at":"2024-06-01T12:00:00+00:00",
             "updated_at":"2024-06-01T12:00:00+00:00"}
            """.utf8)
        try await store.enqueueRaw(kind: .update, table: "stock_products", id: id,
                                   payload: blob, updatedAt: .now)

        try await engine.push()

        let obj = try await pushedObject(gw)
        #expect(obj["icon"] == nil)
        #expect(obj["name"] as? String == "Milk")
        #expect(obj["level"] as? String == "low")
        #expect(obj["packages"] == nil)
        #expect(obj["loose_units"] == nil)
        #expect(obj["units_per_package"] == nil)
        #expect(obj["needed"] as? Bool == true)
    }

    @Test("a current-shape task payload round-trips unchanged through push")
    func currentTaskPayloadRoundTrips() async throws {
        let (engine, store, gw) = try await make()
        let task = HouseholdTask(title: "Filter", section: .garden, intervalDays: 30,
                                 nextDueDate: Date(timeIntervalSince1970: 1_700_000_000),
                                 updatedAt: Date(timeIntervalSince1970: 1_700_000_100))
        try await store.upsert([task], enqueue: true)

        try await engine.push()

        let payloads = await gw.pushedPayloads()
        let data = try #require(payloads.first)
        let decoded = try SyncDateCoding.makeDecoder().decode(HouseholdTask.self, from: data)
        #expect(decoded == task)
    }
}

@Suite("SyncEngine pull") @MainActor struct SyncEnginePullTests {
    private func make() async throws -> (SyncEngine, LocalStore, FakeGateway) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sp-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gw = FakeGateway()
        return (SyncEngine(local: store, gateway: gw), store, gw)
    }

    private func blob(id: UUID, name: String, updatedAt: Date, deletedAt: Date? = nil) throws -> Data {
        let p = StockProduct(id: id, name: name, level: .full, updatedAt: updatedAt, deletedAt: deletedAt)
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
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
        let newer = StockProduct(id: id, name: "Local", level: .full, updatedAt: .now)
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
        try await store.upsert([StockProduct(id: id, name: "Milk", level: .full)], enqueue: false)
        await gw.setPull("stock_products",
                         [try blob(id: id, name: "Milk", updatedAt: .now.addingTimeInterval(60),
                                   deletedAt: .now.addingTimeInterval(60))])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).isEmpty)
    }

    @Test("equal updatedAt: remote wins (tie goes to server)")
    func equalTimestampRemoteWins() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        let ts = Date.now
        let local = StockProduct(id: id, name: "Local", level: .full, updatedAt: ts)
        try await store.upsert([local], enqueue: false)
        await gw.setPull("stock_products", [try blob(id: id, name: "Remote", updatedAt: ts)])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Remote"])
    }

    @Test("pull decodes Postgres timestamps with fractional seconds")
    func pullFractionalSeconds() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        let json: [String: Any] = [
            "id": id.uuidString, "name": "Milk", "icon": "i",
            "packages": 1, "loose_units": 0, "units_per_package": 6,
            "created_at": "2024-06-01T12:00:00.123456+00:00",
            "updated_at": "2024-06-01T12:00:00.654321+00:00"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        await gw.setPull("stock_products", [data])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Milk"])
    }

    @Test("cursor is advanced after pull")
    func cursorAdvanced() async throws {
        let (engine, store, gw) = try await make()
        let ts = Date.now
        await gw.setPull("stock_products", [try blob(id: UUID(), name: "Milk", updatedAt: ts)])
        try await engine.pull(table: "stock_products")
        let cursor = try await store.cursor(for: "stock_products")
        #expect(cursor != nil)
    }
}

@Suite("SyncEngine full-sync stamp") @MainActor struct SyncEngineFullSyncStampTests {
    // No default-argument expression here (e.g. `= InMemoryRemote()`): a synchronous
    // actor-init default value in a function signature trips a compiler
    // isolation-inference bug that mis-reports `InMemoryRemote`'s init as invalidly
    // `nonisolated`. Callers pass the gateway explicitly instead.
    private func engine(_ remote: InMemoryRemote) async throws -> SyncEngine {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sfs-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        return SyncEngine(local: store, gateway: remote)
    }

    @Test("a successful full pass stamps lastFullSyncAt")
    func successfulFullPassStamps() async throws {
        let sync = try await engine(InMemoryRemote())
        let before = Date.now
        await sync.sync(tables: SyncEngine.syncedTables)
        let stamped = try #require(await sync.lastFullSyncAt)
        #expect(stamped >= before)
    }

    @Test("a partial sync(tables:) does not set lastFullSyncAt")
    func partialSyncDoesNotStamp() async throws {
        let sync = try await engine(InMemoryRemote())
        await sync.sync(tables: [StockProduct.tableName])
        #expect(await sync.lastFullSyncAt == nil)
    }

    @Test("a failed pass leaves lastFullSyncAt nil")
    func failedPassLeavesNil() async throws {
        let remote = InMemoryRemote()
        await remote.setFailPulls(true)
        let sync = try await engine(remote)
        await sync.sync(tables: SyncEngine.syncedTables)
        #expect(await sync.lastFullSyncAt == nil)
    }

    @Test("a failed pass after a success leaves lastFullSyncAt unchanged")
    func failedPassAfterSuccessLeavesUnchanged() async throws {
        let remote = InMemoryRemote()
        let sync = try await engine(remote)
        await sync.sync(tables: SyncEngine.syncedTables)
        let first = try #require(await sync.lastFullSyncAt)

        await remote.setFailPulls(true)
        await sync.sync(tables: SyncEngine.syncedTables)
        #expect(await sync.lastFullSyncAt == first)
    }

    @Test("a sync that loses the single-flight race does not advance lastFullSyncAt past the running pass")
    func skippedOverlapDoesNotAdvance() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sfs-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gateway = StallingGateway()
        let sync = SyncEngine(local: store, gateway: gateway)

        async let first: Void = sync.sync(tables: SyncEngine.syncedTables)
        await gateway.waitUntilStalling()
        // Overlaps the still-running first pass: single-flight guard skips it immediately
        // and must not touch lastFullSyncAt.
        await sync.sync(tables: SyncEngine.syncedTables)
        #expect(await sync.lastFullSyncAt == nil)

        await first
        #expect(await sync.lastFullSyncAt != nil)
    }
}

/// Minimal gateway that stalls only its first `pull`, so a test can hold a
/// `SyncEngine.sync` pass open long enough to exercise the single-flight overlap path
/// without paying the stall on every one of `syncedTables`. A dedicated, small type
/// (rather than adding a method to `InMemoryRemote`) sidesteps the same
/// default-argument isolation-inference bug worked around above.
///
/// `waitUntilStalling()` lets a test block until the first `pull` has actually begun
/// stalling, instead of racing a fixed `Task.sleep` against the engine's own task
/// scheduling (flaky on slow CI runners — see #88).
actor StallingGateway: RemoteGateway {
    private var hasStalled = false
    private let stalling: AsyncStream<Void>
    private let stallingContinuation: AsyncStream<Void>.Continuation

    init() {
        var continuation: AsyncStream<Void>.Continuation!
        stalling = AsyncStream { continuation = $0 }
        stallingContinuation = continuation
    }

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {}
    func pull(table: String, since: Date?) async throws -> [Data] {
        if !hasStalled {
            hasStalled = true
            stallingContinuation.yield()
            try? await Task.sleep(for: .milliseconds(200))
        }
        return []
    }

    /// Suspends until the first `pull` call has begun stalling.
    func waitUntilStalling() async {
        var iterator = stalling.makeAsyncIterator()
        _ = await iterator.next()
    }
}
