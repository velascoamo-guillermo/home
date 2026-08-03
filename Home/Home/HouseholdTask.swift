import Foundation

nonisolated struct HouseholdTask: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var intervalDays: Int
    var nextDueDate: Date
    var notes: String = ""
    var sectionId: UUID? = nil
    var productId: UUID? = nil
    var quantityPerCompletion: Int = 1
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    func snoozed(byDays days: Int) -> HouseholdTask {
        var copy = self
        copy.nextDueDate = Calendar.current.date(
            byAdding: .day, value: days, to: nextDueDate
        ) ?? nextDueDate
        return copy
    }

    func snoozedByOneDay() -> HouseholdTask { snoozed(byDays: 1) }

    static func defaultDueDate(intervalDays: Int, from date: Date = .now,
                               calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: intervalDays, to: date) ?? date
    }

    enum CodingKeys: String, CodingKey {
        case id, title, icon, notes
        case intervalDays          = "interval_days"
        case nextDueDate           = "next_due_date"
        case sectionId             = "section_id"
        case productId             = "product_id"
        case quantityPerCompletion = "quantity_per_completion"
        case updatedAt             = "updated_at"
        case deletedAt             = "deleted_at"
    }

}

nonisolated extension HouseholdTask: SyncableEntity {
    static let tableName = "household_tasks"
}
