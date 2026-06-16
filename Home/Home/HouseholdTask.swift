import Foundation

struct HouseholdTask: Codable, Identifiable, Hashable {
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

extension HouseholdTask: SyncableEntity {
    static let tableName = "household_tasks"
}
