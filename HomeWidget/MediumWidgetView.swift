import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            eventsColumn
            Divider()
            mealsColumn
        }
        .padding(12)
    }

    private var eventsColumn: some View {
        Link(destination: URL(string: "home://home")!) {
            VStack(alignment: .leading, spacing: 6) {
                if snapshot.events.isEmpty {
                    Text("Nada para hoy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.events) { event in
                        EventRowView(event: event, showSubtitle: false)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mealsColumn: some View {
        Link(destination: URL(string: "home://meals")!) {
            VStack(alignment: .leading, spacing: 8) {
                MealTitleView(meal: snapshot.lunch)
                MealTitleView(meal: snapshot.dinner)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Shared sub-views (used by both Medium and Large)

struct EventRowView: View {
    let event: WidgetEvent
    var showSubtitle: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: event.systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.caption)
                    .lineLimit(1)
                if showSubtitle {
                    Text(event.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct MealTitleView: View {
    let meal: WidgetMeal

    private let widgetAccent = Color(red: 1.0, green: 0.45, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(meal.slot == "lunch" ? "Comida" : "Cena")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if meal.isEmpty {
                Text("Sin planificar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(meal.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(widgetAccent)
                    .lineLimit(2)
            }
        }
    }
}
