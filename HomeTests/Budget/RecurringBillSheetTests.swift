import Testing
import Foundation
@testable import Casita

@Suite("Recurring bill form") @MainActor struct RecurringBillSheetTests {
    typealias F = BudgetFixtures

    private func make(name: String = "Internet", amount: String = "20,00", category: UUID? = BudgetFixtures.rent.id,
                      payer: UUID? = BudgetFixtures.lu.id, day: Int = 5) throws -> RecurringExpense {
        try RecurringBillSheet.makeBill(id: UUID(), name: name, amountText: amount, categoryId: category,
                                        payerId: payer, dayOfMonth: day, active: true)
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
}
