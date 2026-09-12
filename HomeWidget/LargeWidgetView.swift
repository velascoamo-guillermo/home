import AppIntents
import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            eventsSection
            Divider()
                .padding(.vertical, 10)
            mealsSection
        }
        .padding(16)
    }

    // MARK: - Events

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: "home://home")!) {
                WidgetSectionHeader(systemImage: "checklist", title: "Hoy", tint: Palette.tasks)
            }
            if snapshot.events.isEmpty {
                Link(destination: URL(string: "home://home")!) {
                    Text("Nada para hoy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(snapshot.events) { event in
                        HStack(spacing: 6) {
                            Link(destination: URL(string: "home://home")!) {
                                EventRowView(event: event, showSubtitle: true)
                            }
                            if event.kind == .task {
                                Button(intent: CompleteTaskIntent(taskId: event.id.uuidString)) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.tint)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Meals

    private var mealsSection: some View {
        Link(destination: URL(string: "home://meals")!) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetSectionHeader(systemImage: "fork.knife", title: "Menú", tint: Palette.meals)
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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Large-only sub-view

struct MealDetailView: View {
    let meal: WidgetMeal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(meal.slot == "lunch" ? "Comida" : "Cena")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if meal.isShort {
                    Text("Falta stock")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            Text(meal.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
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
