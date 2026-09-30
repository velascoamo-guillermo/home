import Testing
import Foundation
@testable import Casita

@Suite("Budget sync") @MainActor struct BudgetSyncTests {
    typealias F = BudgetFixtures

    private func device(_ remote: InMemoryRemote) async throws -> (SyncEngine, LocalStore) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("budget-\(UUID().uuidString).sqlite")
        let local = try await LocalStore(url: url)
        return (SyncEngine(local: local, gateway: remote), local)
    }

    @Test("every budget table is synced")
    func tablesListed() {
        for table in ["budget_members", "budget_categories", "budget_incomes",
                      "budget_recurring", "budget_expenses"] {
            #expect(SyncEngine.syncedTables.contains(table), "\(table)")
        }
    }

    private func roundTrip<T: SyncableEntity>(_ item: T) async throws -> [T] {
        let remote = InMemoryRemote()
        let (a, localA) = try await device(remote)
        let (b, localB) = try await device(remote)
        try await localA.upsert([item], enqueue: true)
        try await a.push()
        #expect(try await localA.pendingOps().isEmpty)
        try await b.pull(table: T.tableName)
        return try await localB.fetchAll(T.self)
    }

    @Test("members, categories, incomes, bills and expenses round-trip between devices")
    func roundTrips() async throws {
        #expect(try await roundTrip(F.guille).map(\.name) == ["Guille"])
        #expect(try await roundTrip(F.rent).map(\.estimateCents) == [90_500])
        #expect(try await roundTrip(F.income(380_000, for: F.lu)).map(\.amountCents) == [380_000])
        let bill = RecurringExpense(name: "Internet", amountCents: 2_000, categoryId: F.rent.id,
                                    payerId: F.lu.id, dayOfMonth: 5)
        #expect(try await roundTrip(bill).map(\.dayOfMonth) == [5])
        let expense = F.expense(11_037, by: F.guille)
        let pulled = try await roundTrip(expense)
        #expect(pulled.map(\.id) == [expense.id])
        #expect(pulled.map(\.amountCents) == [11_037])
    }

    @Test("hasPulled is false before any pull and true after an empty pull")
    func hasPulledAfterEmptyPull() async throws {
        let (engine, _) = try await device(InMemoryRemote())
        #expect(await !engine.hasPulled(BudgetMember.tableName))
        try await engine.pull(table: BudgetMember.tableName)
        #expect(await engine.hasPulled(BudgetMember.tableName))
        #expect(await !engine.hasPulled(BudgetCategory.tableName))
    }

    @Test("a failed pull does not mark the table as pulled")
    func failedPullNotMarked() async throws {
        let remote = InMemoryRemote()
        await remote.setFailPulls(true)
        let (engine, _) = try await device(remote)
        await engine.sync(tables: [BudgetMember.tableName])
        #expect(await !engine.hasPulled(BudgetMember.tableName))
    }

    @Test("two devices writing the same member-month income converge on one row, last push wins")
    func sameIncomeTwoDevicesConverge() async throws {
        let remote = InMemoryRemote()
        let (a, localA) = try await device(remote)
        let (b, localB) = try await device(remote)
        let id = BudgetIDs.income(memberId: F.guille.id, month: F.november)
        try await localA.upsert([BudgetIncome(id: id, memberId: F.guille.id, month: "2026-11",
                                              amountCents: 300_000)], enqueue: true)
        try await localB.upsert([BudgetIncome(id: id, memberId: F.guille.id, month: "2026-11",
                                              amountCents: 310_000)], enqueue: true)
        try await a.push()
        try await b.push()
        #expect(try await localA.pendingOps().isEmpty)
        #expect(try await localB.pendingOps().isEmpty)
        #expect(await remote.rowCount(BudgetIncome.tableName) == 1)
        try await a.pull(table: BudgetIncome.tableName)
        #expect(try await localA.fetchAll(BudgetIncome.self).map(\.amountCents) == [310_000])
    }

    @Test("re-creating a tombstoned deterministic row clears deleted_at remotely")
    func recreatedRowClearsRemoteTombstone() async throws {
        let remote = InMemoryRemote()
        let (a, localA) = try await device(remote)
        let (b, localB) = try await device(remote)
        let income = BudgetIncome(id: BudgetIDs.income(memberId: F.lu.id, month: F.november),
                                  memberId: F.lu.id, month: "2026-11", amountCents: 100_000)
        try await localA.upsert([income], enqueue: true)
        try await a.push()
        try await localA.softDelete(income, enqueue: true)
        try await a.push()
        var again = income
        again.updatedAt = .now
        try await localA.upsert([again], enqueue: true)
        try await a.push()
        #expect(await remote.deletedAtIsNull(BudgetIncome.tableName, id: income.id))
        try await b.pull(table: BudgetIncome.tableName)
        #expect(try await localB.fetchAll(BudgetIncome.self).map(\.id) == [income.id])
    }

    @Test("two devices confirming the same bill for the same month end up with one expense")
    func sameBillTwoDevicesConverge() async throws {
        let remote = InMemoryRemote()
        let (a, localA) = try await device(remote)
        let (b, localB) = try await device(remote)
        let bill = RecurringExpense(name: "Luz", amountCents: 11_000, categoryId: F.rent.id,
                                    payerId: F.guille.id, dayOfMonth: 10)
        var onA = ExpenseDraft(confirming: bill, month: F.november, calendar: F.calendar)
        onA.amountText = "108.40"
        var onB = ExpenseDraft(confirming: bill, month: F.november, calendar: F.calendar)
        onB.amountText = "112.15"
        try await localA.upsert([onA.makeExpense()], enqueue: true)
        try await localB.upsert([onB.makeExpense()], enqueue: true)
        try await a.push()
        try await b.push()
        #expect(await remote.rowCount(BudgetExpense.tableName) == 1)
        try await a.pull(table: BudgetExpense.tableName)
        let onDeviceA = try await localA.fetchAll(BudgetExpense.self)
        #expect(onDeviceA.count == 1)
        #expect(onDeviceA.first?.amountCents == 11_215)
    }

    @Test("deleting then re-confirming a bill clears the remote tombstone and stays one row")
    func reconfirmedBillClearsRemoteTombstone() async throws {
        let remote = InMemoryRemote()
        let (a, localA) = try await device(remote)
        let (b, localB) = try await device(remote)
        let bill = RecurringExpense(name: "Agua", amountCents: 3_000, categoryId: F.rent.id,
                                    payerId: F.guille.id, dayOfMonth: 12)
        let first = try ExpenseDraft(confirming: bill, month: F.november, calendar: F.calendar).makeExpense()
        try await localA.upsert([first], enqueue: true)
        try await a.push()
        try await localA.softDelete(first, enqueue: true)
        try await a.push()
        #expect(await remote.deletedAtIsNull(BudgetExpense.tableName, id: first.id) == false)
        var again = try ExpenseDraft(confirming: bill, month: F.november, calendar: F.calendar).makeExpense()
        again.updatedAt = .now
        try await localA.upsert([again], enqueue: true)
        try await a.push()
        #expect(await remote.rowCount(BudgetExpense.tableName) == 1)
        #expect(await remote.deletedAtIsNull(BudgetExpense.tableName, id: first.id))
        try await b.pull(table: BudgetExpense.tableName)
        let onB = try await localB.fetchAll(BudgetExpense.self)
        #expect(onB.count == 1)
        #expect(onB.first?.id == first.id)
        #expect(onB.first?.deletedAt == nil)
    }
}
