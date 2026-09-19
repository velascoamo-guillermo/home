import Foundation

// nonisolated: these types cross the app/widget process boundary via JSON;
// they must not be bound to any actor isolation.
nonisolated struct WidgetSnapshot: Codable, Sendable {
    var generatedAt: Date
    var events: [WidgetEvent]
    var lunch: WidgetMeal
    var dinner: WidgetMeal
}

nonisolated struct WidgetEvent: Codable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case appointment, task
    }
    var id: UUID
    var title: String
    var subtitle: String
    var date: Date
    var kind: Kind
}

extension WidgetEvent {
    // Shared by WidgetSnapshotWriter and CompleteTaskIntent so task subtitles stay identical.
    nonisolated init(task: HouseholdTask, productName: String?, now: Date = .now) {
        let base = task.notes.isEmpty
            ? task.nextDueDate.formatted(date: .abbreviated, time: .omitted)
            : task.notes
        var subtitle = base
        if task.productId != nil, let productName {
            subtitle = "\(base) · \(productName)"
        }
        self.init(
            id: task.id,
            title: task.title,
            subtitle: subtitle,
            date: task.nextDueDate,
            kind: .task
        )
    }
}

nonisolated struct WidgetMeal: Codable, Sendable {
    var slot: String        // "lunch" | "dinner"
    var title: String
    var products: [String]
    var isShort: Bool
    var isEmpty: Bool
}

// MARK: - Placeholder

extension WidgetSnapshot {
    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: .now,
            events: [
                WidgetEvent(id: UUID(), title: "Cita veterinario", subtitle: "Max",
                            date: .now.addingTimeInterval(3600), kind: .appointment),
                WidgetEvent(id: UUID(), title: "Cambiar filtro agua", subtitle: "Cocina",
                            date: .now.addingTimeInterval(86400), kind: .task),
            ],
            lunch: WidgetMeal(slot: "lunch", title: "Ensalada mediterránea", products: [], isShort: false, isEmpty: false),
            dinner: WidgetMeal(slot: "dinner", title: "Pasta boloñesa", products: [], isShort: false, isEmpty: false)
        )
    }
}
