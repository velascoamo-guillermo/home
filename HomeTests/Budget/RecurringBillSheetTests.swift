import Testing
import Foundation
@testable import Casita

@Suite("Recurring bill form") @MainActor struct RecurringBillSheetTests {
    typealias F = BudgetFixtures

    private func make(name: String = "Internet", amount: String = "20,00", category: UUID? = BudgetFixtures.rent.id,
                      payer: UUID? = BudgetFixtures.lu.id, day: Int = 5) throws -> RecurringExpense {
        var draft = RecurringBillDraft(existing: nil)
        draft.name = name
        draft.amountText = amount
        draft.categoryId = category
        draft.payerId = payer
        draft.dayOfMonth = day
        return try draft.makeBill()
    }

    @Test("builds a bill in cents with a trimmed name")
    func valid() throws {
        let bill = try make(name: " Internet ")
        #expect(bill.name == "Internet")
        #expect(bill.amountCents == 2_000)
        #expect(bill.dayOfMonth == 5)
    }

    @Test("reports the first invalid field")
    func invalid() {
        #expect(throws: BudgetValidationError.emptyName) { try make(name: "") }
        #expect(throws: BudgetValidationError.invalidAmount) { try make(amount: "x") }
        #expect(throws: BudgetValidationError.missingCategory) { try make(category: nil) }
        #expect(throws: BudgetValidationError.missingPayer) { try make(payer: nil) }
        #expect(throws: BudgetValidationError.dayOutOfRange) { try make(day: 31) }
    }

    @Test("a new bill keeps one id across repeated saves")
    func newBillIdIsStable() throws {
        var draft = RecurringBillDraft(existing: nil)
        draft.name = "Internet"
        draft.amountText = "20"
        draft.categoryId = F.rent.id
        draft.payerId = F.lu.id
        let first = try draft.makeBill()
        draft.amountText = "21"
        #expect(try draft.makeBill().id == first.id)
    }

    @Test("editing an existing bill keeps its id and fields")
    func existingBill() throws {
        let bill = RecurringExpense(name: "Luz", amountCents: 4_550, categoryId: F.rent.id,
                                    payerId: F.guille.id, dayOfMonth: 12, active: false)
        let draft = RecurringBillDraft(existing: bill)
        #expect(!draft.isNew)
        #expect(draft.amountText == Money.editText(cents: 4_550))
        let rebuilt = try draft.makeBill()
        #expect(rebuilt.id == bill.id)
        #expect(rebuilt.dayOfMonth == 12)
        #expect(rebuilt.active == false)
    }
}
