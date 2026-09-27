import Testing
import Foundation
@testable import Casita

@Suite("Budget model coding") @MainActor struct BudgetModelCodingTests {

    private func encode<T: Encodable>(_ value: T) throws -> (json: [String: Any], raw: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return (json, String(decoding: data, as: UTF8.self))
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try SyncDateCoding.makeDecoder().decode(T.self, from: encoder.encode(value))
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_793_000_000)

    @Test("table names match the migration")
    func tableNames() {
        #expect(BudgetMember.tableName == "budget_members")
        #expect(BudgetCategory.tableName == "budget_categories")
        #expect(BudgetIncome.tableName == "budget_incomes")
        #expect(RecurringExpense.tableName == "budget_recurring")
        #expect(BudgetExpense.tableName == "budget_expenses")
    }

    @Test("member encodes snake_case keys and an explicit null deleted_at")
    func member() throws {
        let member = BudgetMember(name: "Guille", sortOrder: 1, updatedAt: fixedDate)
        let (json, _) = try encode(member)
        #expect(json["sort_order"] as? Int == 1)
        #expect(json["updated_at"] != nil)
        #expect(json["deleted_at"] is NSNull)
        #expect(try roundTrip(member) == member)
    }

    @Test("category encodes estimate as integer cents")
    func category() throws {
        let category = BudgetCategory(name: "Luz", estimateCents: 11_000, sortOrder: 3,
                                      archived: true, updatedAt: fixedDate)
        let (json, raw) = try encode(category)
        #expect(raw.contains("\"estimate_cents\":11000"))
        #expect(json["archived"] as? Bool == true)
        #expect(json["deleted_at"] is NSNull)
        #expect(try roundTrip(category) == category)
    }

    @Test("income encodes member_id, month key and cents")
    func income() throws {
        let memberId = UUID()
        let income = BudgetIncome(memberId: memberId, month: "2026-11", amountCents: 380_000,
                                  updatedAt: fixedDate)
        let (json, raw) = try encode(income)
        #expect(json["member_id"] as? String == memberId.uuidString)
        #expect(json["month"] as? String == "2026-11")
        #expect(raw.contains("\"amount_cents\":380000"))
        #expect(json["deleted_at"] is NSNull)
        #expect(try roundTrip(income) == income)
    }

    @Test("recurring bill encodes day_of_month, active and foreign keys")
    func recurring() throws {
        let bill = RecurringExpense(name: "Internet", amountCents: 2_000, categoryId: UUID(),
                                    payerId: UUID(), dayOfMonth: 5, active: false,
                                    updatedAt: fixedDate)
        let (json, raw) = try encode(bill)
        #expect(json["day_of_month"] as? Int == 5)
        #expect(json["active"] as? Bool == false)
        #expect(json["category_id"] != nil)
        #expect(json["payer_id"] != nil)
        #expect(raw.contains("\"amount_cents\":2000"))
        #expect(json["deleted_at"] is NSNull)
        #expect(try roundTrip(bill) == bill)
    }

    @Test("expense always encodes recurring_id and deleted_at, even when nil")
    func expense() throws {
        let expense = BudgetExpense(name: "Mercadona", amountCents: 4_537, categoryId: UUID(),
                                    payerId: UUID(), date: fixedDate, updatedAt: fixedDate)
        let (json, raw) = try encode(expense)
        #expect(raw.contains("\"amount_cents\":4537"))
        #expect(json["recurring_id"] is NSNull)
        #expect(json["deleted_at"] is NSNull)
        #expect(json["date"] as? String != nil)
        #expect(try roundTrip(expense) == expense)
    }

    @Test("expense decodes a PostgREST row with fractional-second timestamps")
    func expenseFromPostgres() throws {
        let id = UUID(), category = UUID(), payer = UUID(), bill = UUID()
        let row = Data("""
            {"id":"\(id.uuidString.lowercased())","name":"","amount_cents":90500,
             "category_id":"\(category.uuidString.lowercased())",
             "payer_id":"\(payer.uuidString.lowercased())",
             "date":"2026-11-01T09:00:00.123456+00:00",
             "recurring_id":"\(bill.uuidString.lowercased())",
             "updated_at":"2026-11-01T09:00:01.5+00:00","deleted_at":null}
            """.utf8)
        let decoded = try SyncDateCoding.makeDecoder().decode(BudgetExpense.self, from: row)
        #expect(decoded.id == id)
        #expect(decoded.amountCents == 90_500)
        #expect(decoded.recurringId == bill)
        #expect(decoded.deletedAt == nil)
    }
}
