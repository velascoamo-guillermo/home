import Testing
import Foundation
@testable import Casita

@Suite("Budget settings mutations") @MainActor struct BudgetSettingsStoreTests {
    typealias F = BudgetFixtures

    private func seeded(url: URL = BudgetFixtures.tempURL()) async throws -> SupabaseStore {
        let store = await F.makeStore(url: url)
        try await store.seedBudgetDefaults()
        return store
    }

    private func summary(_ store: SupabaseStore, _ month: BudgetMonth = BudgetFixtures.november) -> MonthSummary {
        store.budgetSummary(for: month, today: F.date(2026, 11, 15), calendar: F.calendar)
    }

    @Test("adding a member appends it with the next sort order")
    func addMember() async throws {
        let store = try await seeded()
        try await store.addBudgetMember(name: " Ana ")
        #expect(store.budgetMembers.map(\.name) == ["Guille", "Lu", "Ana"])
        #expect(store.budgetMembers.last?.sortOrder == 2)
    }

    @Test("empty member names are rejected")
    func emptyMemberName() async throws {
        let store = try await seeded()
        await #expect(throws: BudgetValidationError.emptyName) { try await store.addBudgetMember(name: "   ") }
        let lu = try #require(store.budgetMembers.last)
        await #expect(throws: BudgetValidationError.emptyName) { try await store.renameBudgetMember(lu, to: "") }
    }

    @Test("renaming a member persists")
    func renameMember() async throws {
        let url = F.tempURL()
        let store = try await seeded(url: url)
        let lu = try #require(store.budgetMembers.last)
        try await store.renameBudgetMember(lu, to: "Lucía")
        #expect(await F.makeStore(url: url).budgetMembers.map(\.name) == ["Guille", "Lucía"])
    }

    @Test("removing a member keeps their expenses as Former member")
    func deleteMemberKeepsExpenses() async throws {
        let store = try await seeded()
        let lu = try #require(store.budgetMembers.last)
        let food = try #require(store.budgetCategories.first { $0.name == "Supermercado" })
        try await store.saveBudgetExpense(BudgetExpense(amountCents: 1_000, categoryId: food.id,
                                                        payerId: lu.id, date: F.date(2026, 11, 3)))
        try await store.deleteBudgetMember(lu)
        #expect(store.budgetMembers.map(\.name) == ["Guille"])
        let former = try #require(summary(store).members.first { $0.isFormer })
        #expect(former.paidCents == 1_000)
        #expect(summary(store).totalCents == 1_000)
    }

    @Test("deleting the last live member is refused")
    func deleteLastMemberRefused() async throws {
        let store = try await seeded()
        let guille = try #require(store.budgetMembers.first { $0.name == "Guille" })
        let lu = try #require(store.budgetMembers.first { $0.name == "Lu" })
        try await store.deleteBudgetMember(lu)
        #expect(store.budgetMembers.map(\.name) == ["Guille"])
        await #expect(throws: BudgetValidationError.lastMember) { try await store.deleteBudgetMember(guille) }
        #expect(store.budgetMembers.map(\.name) == ["Guille"])
    }

    @Test("setting the same member-month income twice keeps one row")
    func setIncomeTwiceKeepsOneRow() async throws {
        let url = F.tempURL()
        let store = try await seeded(url: url)
        let guille = try #require(store.budgetMembers.first)
        try await store.setBudgetIncome(memberId: guille.id, month: F.november, amountCents: 300_000)
        try await store.setBudgetIncome(memberId: guille.id, month: F.november, amountCents: 310_000)
        #expect(store.budgetIncomes.map(\.amountCents) == [310_000])
        #expect(store.budgetIncomes.first?.id == BudgetIDs.income(memberId: guille.id, month: F.november))
        #expect(await F.makeStore(url: url).budgetIncomes.count == 1)
    }

    @Test("income can be zero but not negative")
    func incomeBounds() async throws {
        let store = try await seeded()
        let guille = try #require(store.budgetMembers.first)
        try await store.setBudgetIncome(memberId: guille.id, month: F.november, amountCents: 0)
        await #expect(throws: BudgetValidationError.invalidAmount) {
            try await store.setBudgetIncome(memberId: guille.id, month: F.november, amountCents: -1)
        }
    }

    @Test("October income carries into November until November gets its own")
    func carryOver() async throws {
        let store = try await seeded()
        let guille = try #require(store.budgetMembers.first)
        try await store.setBudgetIncome(memberId: guille.id, month: F.november.previous, amountCents: 380_000)
        let line = try #require(summary(store).members.first { $0.id == guille.id })
        #expect(line.incomeCents == 380_000)
        #expect(line.incomeCarriedOver)
    }

    @Test("a category with expenses cannot be deleted; an unused one can")
    func deleteCategory() async throws {
        let store = try await seeded()
        let rent = try #require(store.budgetCategories.first)
        let other = try #require(store.budgetCategories.last)
        let guille = try #require(store.budgetMembers.first)
        try await store.saveBudgetExpense(BudgetExpense(amountCents: 90_500, categoryId: rent.id,
                                                        payerId: guille.id, date: F.date(2026, 11, 1)))
        await #expect(throws: BudgetValidationError.categoryInUse) { try await store.deleteBudgetCategory(rent) }
        try await store.deleteBudgetCategory(other)
        #expect(store.budgetCategories.count == 13)
        #expect(store.budgetCategories.contains { $0.id == rent.id })
    }

    @Test("archiving drops the estimate from the month total")
    func archive() async throws {
        let store = try await seeded()
        #expect(summary(store).estimateCents == 185_500)
        let rent = try #require(store.budgetCategories.first)
        try await store.setBudgetCategoryArchived(rent, archived: true)
        #expect(summary(store).estimateCents == 95_000)
        #expect(store.budgetCategories.first { $0.id == rent.id }?.archived == true)
    }

    @Test("saving a category validates name and estimate")
    func saveCategoryValidation() async throws {
        let store = try await seeded()
        await #expect(throws: BudgetValidationError.emptyName) {
            try await store.saveBudgetCategory(BudgetCategory(name: " ", estimateCents: 100))
        }
        await #expect(throws: BudgetValidationError.invalidAmount) {
            try await store.saveBudgetCategory(BudgetCategory(name: "Viajes", estimateCents: -1))
        }
        try await store.saveBudgetCategory(BudgetCategory(name: "Viajes", estimateCents: 0, sortOrder: 14))
        #expect(store.budgetCategories.last?.name == "Viajes")
    }

    @Test("reordering rewrites sort order to match the given order")
    func reorder() async throws {
        let url = F.tempURL()
        let store = try await seeded(url: url)
        let reversed = Array(store.budgetCategories.reversed())
        try await store.reorderBudgetCategories(reversed)
        #expect(store.budgetCategories.map(\.name) == reversed.map(\.name))
        #expect(store.budgetCategories.map(\.sortOrder) == Array(0..<14))
        #expect(await F.makeStore(url: url).budgetCategories.first?.name == "Otros")
    }
}
