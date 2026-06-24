import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            eventsSection
            Divider()
                .padding(.vertical, 8)
            mealsSection
        }
        .padding(14)
    }

    // MARK: - Events

    private var eventsSection: some View {
        Link(destination: URL(string: "home://home")!) {
            VStack(alignment: .leading, spacing: 8) {
                if snapshot.events.isEmpty {
                    Text("Nada para hoy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.events) { event in
                        EventRowView(event: event, showSubtitle: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Meals

    private var mealsSection: some View {
        Link(destination: URL(string: "home://meals")!) {
            if snapshot.lunch.isEmpty && snapshot.dinner.isEmpty {
                Text("Sin comidas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if !snapshot.lunch.isEmpty {
                        MealDetailView(meal: snapshot.lunch)
                    }
                    if !snapshot.dinner.isEmpty {
                        MealDetailView(meal: snapshot.dinner)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Large-only sub-view

struct MealDetailView: View {
    let meal: WidgetMeal

    private let accent = Color(red: 1.0, green: 0.45, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(meal.slot == "lunch" ? "Comida" : "Cena")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if meal.isShort {
                    Text("Falta stock")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(accent)
                        .clipShape(.rect(cornerRadius: 4))
                }
            }
            Text(meal.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(accent)
                .lineLimit(1)
            if !meal.products.isEmpty {
                Text(meal.products.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
