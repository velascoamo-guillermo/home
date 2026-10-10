import Testing
import Foundation
@testable import Casita

@Suite("Budget deterministic IDs") @MainActor struct BudgetIDsTests {

    @Test("matches the RFC 4122 v5 reference vector (DNS namespace, python.org)")
    func rfcVector() throws {
        let dns = try #require(UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
        #expect(UUID.nameBased(namespace: dns, name: "python.org")
                == UUID(uuidString: "886313e1-3b8a-5372-9b90-0c9aee199e5d"))
    }

    @Test("sets version 5 and the RFC 4122 variant")
    func versionAndVariant() {
        let id = BudgetIDs.member(name: "Lu")
        #expect(id.uuid.6 >> 4 == 5)
        #expect(id.uuid.8 >> 6 == 0b10)
    }

    @Test("seeded member and category IDs are pinned")
    func pinnedSeeds() {
        #expect(BudgetIDs.namespace == UUID(uuidString: "6F1C1B0E-3D2A-4C55-9A8E-4B7DE0B6A1C2"))
        #expect(BudgetIDs.member(name: "Guille") == UUID(uuidString: "6911c36d-4b2e-5af7-8f60-c2b39fce7ae8"))
        #expect(BudgetIDs.category(name: "Alquiler") == UUID(uuidString: "b9ce305f-7cae-5f40-977a-84db810195b1"))
    }

    @Test("same inputs give the same ID; a different month gives a different ID")
    func deterministic() {
        let member = UUID()
        let nov = BudgetMonth(year: 2026, month: 11)
        #expect(BudgetIDs.income(memberId: member, month: nov) == BudgetIDs.income(memberId: member, month: nov))
        #expect(BudgetIDs.income(memberId: member, month: nov) != BudgetIDs.income(memberId: member, month: nov.next))
        let bill = UUID()
        #expect(BudgetIDs.recurringExpense(recurringId: bill, month: nov)
                == BudgetIDs.recurringExpense(recurringId: bill, month: nov))
        #expect(BudgetIDs.recurringExpense(recurringId: bill, month: nov)
                != BudgetIDs.recurringExpense(recurringId: bill, month: nov.previous))
    }

    @Test("an income ID and a recurring ID over the same UUID and month never collide")
    func prefixesSeparateKinds() {
        let shared = UUID()
        let nov = BudgetMonth(year: 2026, month: 11)
        #expect(BudgetIDs.income(memberId: shared, month: nov)
                != BudgetIDs.recurringExpense(recurringId: shared, month: nov))
    }

    @Test("uuid case in the name does not matter: IDs use the lowercased form")
    func lowercasedIdentity() throws {
        let upper = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let nov = BudgetMonth(year: 2026, month: 11)
        #expect(BudgetIDs.income(memberId: upper, month: nov)
                == UUID.nameBased(namespace: BudgetIDs.namespace,
                                  name: "budget-income:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:2026-11"))
    }
}
