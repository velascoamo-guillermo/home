import Foundation

nonisolated struct HouseholdTask: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var section: TaskSection.Predefined = .general
    var intervalDays: Int
    var nextDueDate: Date
    var notes: String = ""
    var sectionId: UUID? = nil
    var productId: UUID? = nil
    var quantityPerCompletion: Int = 1
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    init(id: UUID = UUID(), title: String, section: TaskSection.Predefined = .general,
         intervalDays: Int, nextDueDate: Date, notes: String = "",
         sectionId: UUID? = nil, productId: UUID? = nil, quantityPerCompletion: Int = 1,
         updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.section = section
        self.intervalDays = intervalDays
        self.nextDueDate = nextDueDate
        self.notes = notes
        self.sectionId = sectionId
        self.productId = productId
        self.quantityPerCompletion = quantityPerCompletion
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

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
        case id, title, section, notes
        case legacyIcon            = "icon"
        case intervalDays          = "interval_days"
        case nextDueDate           = "next_due_date"
        case sectionId             = "section_id"
        case productId             = "product_id"
        case quantityPerCompletion = "quantity_per_completion"
        case updatedAt             = "updated_at"
        case deletedAt             = "deleted_at"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        if let key = try c.decodeIfPresent(TaskSection.Predefined.self, forKey: .section) {
            section = key
        } else if let icon = try c.decodeIfPresent(String.self, forKey: .legacyIcon) {
            section = TaskSection.Predefined(legacyIcon: icon)
        } else {
            section = .general
        }
        intervalDays = try c.decode(Int.self, forKey: .intervalDays)
        nextDueDate = try c.decode(Date.self, forKey: .nextDueDate)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        sectionId = try c.decodeIfPresent(UUID.self, forKey: .sectionId)
        productId = try c.decodeIfPresent(UUID.self, forKey: .productId)
        quantityPerCompletion = try c.decodeIfPresent(Int.self, forKey: .quantityPerCompletion) ?? 1
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? .now
        deletedAt = try? c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(section, forKey: .section)
        try c.encode(intervalDays, forKey: .intervalDays)
        try c.encode(nextDueDate, forKey: .nextDueDate)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(sectionId, forKey: .sectionId)
        try c.encodeIfPresent(productId, forKey: .productId)
        try c.encode(quantityPerCompletion, forKey: .quantityPerCompletion)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

nonisolated extension HouseholdTask: SyncableEntity {
    static let tableName = "household_tasks"
}
