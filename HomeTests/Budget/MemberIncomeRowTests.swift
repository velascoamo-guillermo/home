import Testing
import Foundation
@testable import Casita

@Suite("Member income commit") @MainActor struct MemberIncomeRowTests {
    private func line(income: Int, carried: Bool) -> MemberLine {
        MemberLine(id: UUID(), name: "Lu", isFormer: false, sortOrder: 1, incomeCents: income,
                   incomeCarriedOver: carried, ratioPercent: 50, shareCents: 0, paidCents: 0,
                   balanceCents: 0, savingsCents: income)
    }

    @Test("unchanged text writes nothing, so a carried-over income stays inherited")
    func unchanged() throws {
        #expect(try MemberIncomeRow.incomeToSave(text: "1000.00", current: line(income: 100_000, carried: true)) == nil)
        #expect(try MemberIncomeRow.incomeToSave(text: "1000,00", current: line(income: 100_000, carried: false)) == nil)
    }

    @Test("a changed value is saved in cents, zero included")
    func changed() throws {
        #expect(try MemberIncomeRow.incomeToSave(text: "1050,5", current: line(income: 100_000, carried: true)) == 105_050)
        #expect(try MemberIncomeRow.incomeToSave(text: "0", current: line(income: 100_000, carried: false)) == 0)
    }

    @Test("garbage and oversize values are rejected")
    func invalid() {
        #expect(throws: BudgetValidationError.invalidAmount) {
            try MemberIncomeRow.incomeToSave(text: "abc", current: line(income: 0, carried: false))
        }
        #expect(throws: BudgetValidationError.amountTooLarge) {
            try MemberIncomeRow.incomeToSave(text: "1000000,01", current: line(income: 0, carried: false))
        }
    }

    @Test("a name equal to the current one after trimming writes nothing")
    func nameUnchanged() {
        #expect(MemberIncomeRow.nameToSave(text: "Lu", current: line(income: 0, carried: false)) == nil)
        #expect(MemberIncomeRow.nameToSave(text: " Lu ", current: line(income: 0, carried: false)) == nil)
    }

    @Test("a changed name is saved trimmed; an empty one is passed on so validation reports it")
    func nameChanged() {
        #expect(MemberIncomeRow.nameToSave(text: " Lucía ", current: line(income: 0, carried: false)) == "Lucía")
        #expect(MemberIncomeRow.nameToSave(text: "  ", current: line(income: 0, carried: false)) == "")
    }

    @Test("an incoming value replaces the field unless the user is editing it")
    func resync() {
        #expect(MemberIncomeRow.resynced(local: "1000,00", incoming: "1200,00", isEditing: false) == "1200,00")
        #expect(MemberIncomeRow.resynced(local: "1000,5", incoming: "1200,00", isEditing: true) == "1000,5")
    }
}
