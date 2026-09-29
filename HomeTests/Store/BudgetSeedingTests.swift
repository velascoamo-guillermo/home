import Testing
import Foundation
import Supabase
@testable import Casita

@Suite("Budget seeding and hydration") @MainActor struct BudgetSeedingTests {
    typealias F = BudgetFixtures

    @Test("seed data: Guille and Lu, 14 categories totalling €1,855.00, deterministic IDs")
    func seedContents() {
        #expect(BudgetSeed.members().map(\.name) == ["Guille", "Lu"])
        #expect(BudgetSeed.members().map(\.sortOrder) == [0, 1])
        #expect(BudgetSeed.members().first?.id == BudgetIDs.member(name: "Guille"))
        let categories = BudgetSeed.categories()
        #expect(categories.count == 14)
        #expect(categories.first?.name == "Alquiler")
        #expect(categories.first?.id == BudgetIDs.category(name: "Alquiler"))
        #expect(categories.map(\.name).contains("Ropa y complementos"))
        #expect(categories.reduce(0) { $0 + $1.estimateCents } == 185_500)
        #expect(categories.map(\.sortOrder) == Array(0..<14))
    }

    @Test("seeds after the first successful pull when the remote is empty")
    func seedsAfterFirstPull() async throws {
        let store = await F.makeStore(syncEnabled: true, gateway: InMemoryRemote())
        try await F.waitUntil { store.budgetCategories.count == 14 }
        #expect(store.budgetMembers.map(\.name) == ["Guille", "Lu"])
        #expect(store.budgetCategories.count == 14)
    }

    @Test("does not seed when the pull fails (offline first launch)")
    func noSeedWhenPullFails() async throws {
        let remote = InMemoryRemote()
        await remote.setFailPulls(true)
        let store = await F.makeStore(syncEnabled: true, gateway: remote)
        try await Task.sleep(for: .milliseconds(300))
        #expect(store.budgetMembers.isEmpty)
        #expect(store.budgetCategories.isEmpty)
    }

    @Test("seeds on a later successful sync once the network recovers")
    func seedsAfterRecovery() async throws {
        let remote = InMemoryRemote()
        await remote.setFailPulls(true)
        let store = await F.makeStore(syncEnabled: true, gateway: remote)
        await remote.setFailPulls(false)
        await store.refreshFromLocal()
        try await F.waitUntil { store.budgetMembers.count == 2 }
        #expect(store.budgetMembers.map(\.name) == ["Guille", "Lu"])
    }

    @Test("does not seed when the remote already has budget rows")
    func noSeedWhenRemoteHasRows() async throws {
        let remote = InMemoryRemote()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try await remote.push(kind: .insert, table: BudgetMember.tableName,
                              payload: encoder.encode(BudgetMember(name: "Ana")))
        let store = await F.makeStore(syncEnabled: true, gateway: remote)
        try await F.waitUntil { !store.budgetMembers.isEmpty }
        try await Task.sleep(for: .milliseconds(200))
        #expect(store.budgetMembers.map(\.name) == ["Ana"])
        #expect(store.budgetCategories.isEmpty)
    }

    @Test("never seeds when sync is disabled")
    func noSeedWithoutSync() async {
        let store = await F.makeStore()
        await store.seedBudgetIfNeeded()
        #expect(store.budgetMembers.isEmpty)
    }

    @Test("seeding twice keeps one row per seed (same deterministic IDs)")
    func seedIdempotent() async throws {
        let url = F.tempURL()
        let store = await F.makeStore(url: url)
        try await store.seedBudgetDefaults()
        try await store.seedBudgetDefaults()
        let reloaded = await F.makeStore(url: url)
        #expect(reloaded.budgetMembers.count == 2)
        #expect(reloaded.budgetCategories.count == 14)
    }

    @Test("hydrate loads every budget array and sorts members/categories by sort order")
    func hydrates() async throws {
        let url = F.tempURL()
        let local = try await LocalStore(url: url)
        try await local.upsert([F.lu, F.guille], enqueue: false)
        try await local.upsert([F.food, F.rent], enqueue: false)
        try await local.upsert([F.income(1, for: F.lu)], enqueue: false)
        try await local.upsert([RecurringExpense(name: "Internet", amountCents: 2_000,
                                                 categoryId: F.rent.id, payerId: F.lu.id,
                                                 dayOfMonth: 5)], enqueue: false)
        try await local.upsert([F.expense(500, by: F.lu)], enqueue: false)
        let store = await F.makeStore(url: url)
        #expect(store.budgetMembers.map(\.name) == ["Guille", "Lu"])
        #expect(store.budgetCategories.map(\.name) == ["Alquiler", "Supermarket"])
        #expect(store.budgetIncomes.count == 1)
        #expect(store.recurringExpenses.count == 1)
        #expect(store.budgetExpenses.count == 1)
    }

    @Test("budgetSummary runs the calculator over the store arrays")
    func summary() async {
        let store = await F.makeStore()
        store.budgetMembers = [F.guille, F.lu]
        store.budgetCategories = [F.rent]
        store.budgetExpenses = [F.expense(1_000, by: F.guille)]
        let s = store.budgetSummary(for: F.november, today: F.date(2026, 11, 15), calendar: F.calendar)
        #expect(s.totalCents == 1_000)
        #expect(s.settlement == [Transfer(fromMemberId: F.lu.id, toMemberId: F.guille.id, amountCents: 500)])
    }

    @Test("does not seed over existing local rows even when the in-memory arrays are stale")
    func noSeedWhenLocalHasRowsButArraysAreStale() async throws {
        let url = F.tempURL()
        let local = try await LocalStore(url: url)
        try await local.upsert([BudgetMember(name: "Ana")], enqueue: false)
        let store = await F.makeStore(syncEnabled: true, gateway: InMemoryRemote(), url: url)
        try await F.waitUntil { !store.budgetMembers.isEmpty }
        // Simulate the reconnect observer racing loadAll's hydrate, or an earlier
        // table throwing inside hydrate: the in-memory arrays go stale/empty even
        // though the local store (and hasPulled) already reflect reality.
        store.budgetMembers = []
        store.budgetCategories = []
        await store.seedBudgetIfNeeded()
        let members = try await local.fetchAll(BudgetMember.self)
        #expect(members.map(\.name) == ["Ana"])
        #expect(try await local.fetchAll(BudgetCategory.self).isEmpty)
    }

    @Test("concurrent seedBudgetIfNeeded calls seed exactly once")
    func concurrentSeedRunsOnce() async throws {
        let url = F.tempURL()
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1")!,
            supabaseKey: "test",
            options: .init(auth: .init(autoRefreshToken: false, emitLocalSessionAsInitialSession: false))
        )
        let remote = InMemoryRemote()
        let store = SupabaseStore(client: client, localURL: url, syncEnabled: true, gateway: remote)
        let local = try await LocalStore(url: url)
        store._local = local
        store._sync = SyncEngine(local: local, gateway: remote)
        await store._sync!.sync(tables: [BudgetMember.tableName, BudgetCategory.tableName])
        #expect(store.budgetMembers.isEmpty)
        #expect(store.budgetCategories.isEmpty)

        async let first: Void = store.seedBudgetIfNeeded()
        async let second: Void = store.seedBudgetIfNeeded()
        _ = await (first, second)

        let members = try await local.fetchAll(BudgetMember.self)
        let categories = try await local.fetchAll(BudgetCategory.self)
        #expect(members.count == 2)
        #expect(categories.count == 14)
        // seedBudgetDefaults syncs at the end, which drains the outbox on a successful
        // push, so a duplicate seeding attempt can't be seen in pendingOps() afterward
        // (and row counts alone wouldn't show it either, since push upserts by id).
        // Count push calls instead: exactly one upsert per seeded row means only one
        // of the two concurrent calls ran seedBudgetDefaults.
        #expect(await remote.pushCount(BudgetMember.tableName) == 2)
        #expect(await remote.pushCount(BudgetCategory.tableName) == 14)
    }
}
