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
                kind: .appointment
            )
        case .task(let task):
            let productName = task.productId.flatMap { pid in
                stockProducts.first(where: { $0.id == pid })?.name
            }
            return WidgetEvent(task: task, productName: productName)
        case .event(let event, let pet):
            return WidgetEvent(
                id: event.id,
                title: event.title,
                subtitle: pet.name,
                date: event.date,
                kind: .appointment
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
