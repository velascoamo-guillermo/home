import Foundation
import WidgetKit

@MainActor
enum WidgetSnapshotWriter {

    static func write(from store: SupabaseStore) {
        let weekday = todayWeekday()
        let lunch  = store.mealEntry(day: weekday, slot: .lunch)
        let dinner = store.mealEntry(day: weekday, slot: .dinner)
        let snapshot = buildSnapshot(
            timeline: store.homeTimeline,
            stockProducts: store.stockProducts,
            lunch: lunch,
            dinner: dinner
        )
        WidgetStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Pure / testable

    nonisolated static func buildSnapshot(
        timeline: [HomeItem],
        stockProducts: [StockProduct],
        lunch: MealEntry?,
        dinner: MealEntry?,
        generatedAt: Date = .now
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: generatedAt,
            events: Array(timeline.prefix(3)).map { widgetEvent(from: $0, stockProducts: stockProducts) },
            lunch:  widgetMeal(from: lunch,  slot: "lunch"),
            dinner: widgetMeal(from: dinner, slot: "dinner")
        )
    }

    nonisolated static func todayWeekday(
        calendar: Calendar = .current,
        date: Date = .now
    ) -> Int {
        let cw = calendar.component(.weekday, from: date) // 1=Sun … 7=Sat
        return (cw + 5) % 7 + 1                           // 1=Mon … 7=Sun
    }

    // MARK: - Private helpers

    private nonisolated static func widgetEvent(
        from item: HomeItem,
        stockProducts: [StockProduct]
    ) -> WidgetEvent {
        switch item {
        case .appointment(let appt, let pet):
            return WidgetEvent(
                id: appt.id,
                title: appt.reason,
                subtitle: pet.name,
                date: appt.date,
                kind: .appointment,
                systemImage: "calendar"
            )
        case .task(let task):
            let base = task.notes.isEmpty
                ? task.nextDueDate.formatted(date: .abbreviated, time: .omitted)
                : task.notes
            var subtitle = base
            if let pid = task.productId,
               let product = stockProducts.first(where: { $0.id == pid }) {
                subtitle = "\(base) · \(product.name) × \(task.quantityPerCompletion)"
            }
            return WidgetEvent(
                id: task.id,
                title: task.title,
                subtitle: subtitle,
                date: task.nextDueDate,
                kind: .task,
                systemImage: task.icon
            )
        }
    }

    private nonisolated static func widgetMeal(from entry: MealEntry?, slot: String) -> WidgetMeal {
        guard let entry else {
            return WidgetMeal(slot: slot, title: "", products: [], isShort: false, isEmpty: true)
        }
        return WidgetMeal(
            slot: slot,
            title: entry.meal.title.isEmpty ? "Sin título" : entry.meal.title,
            products: entry.links.map(\.product.name),
            isShort: entry.isShort,
            isEmpty: false
        )
    }
}
