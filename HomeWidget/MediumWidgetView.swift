import AppIntents
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
        .padding(14)
    }

    private var eventsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: "home://home")!) {
                WidgetSectionHeader(systemImage: "checklist", title: "Hoy", tint: .blue)
            }
            if snapshot.events.isEmpty {
                Link(destination: URL(string: "home://home")!) {
                    Text("Nada para hoy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(snapshot.events) { event in
                        HStack(spacing: 6) {
                            Link(destination: URL(string: "home://home")!) {
                                EventRowView(event: event)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mealsColumn: some View {
        Link(destination: URL(string: "home://meals")!) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetSectionHeader(systemImage: "fork.knife", title: "Menú", tint: .orange)
                VStack(alignment: .leading, spacing: 0) {
                    MealTitleView(meal: snapshot.lunch)
                        .frame(maxHeight: .infinity, alignment: .leading)
                    MealTitleView(meal: snapshot.dinner)
                        .frame(maxHeight: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Shared sub-views (used by both Medium and Large)

struct WidgetSectionHeader: View {
    let systemImage: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.15), in: .rect(cornerRadius: 6))
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.semibold))
        }
    }
}

struct EventRowView: View {
    let event: WidgetEvent
    var showSubtitle: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(event.title)
                .font(.caption.weight(.medium))
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

struct MealTitleView: View {
    let meal: WidgetMeal

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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }
}
