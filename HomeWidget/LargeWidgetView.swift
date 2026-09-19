import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 10) {
            WidgetCard(fill: Palette.tasks) { eventsContent }
                .frame(maxHeight: .infinity)
            Link(destination: URL(string: "home://meals")!) {
                WidgetCard(fill: Palette.meals) { mealsContent }
            }
        }
        .padding(12)
    }

    // MARK: - Events

    private var eventsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: "home://home")!) {
                WidgetSectionHeader(systemImage: "checklist", title: "Hoy")
            }
            if snapshot.events.isEmpty {
                Link(destination: URL(string: "home://home")!) {
                    Text("Nada para hoy")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(snapshot.events) { event in
                        HStack(spacing: 6) {
                            Link(destination: URL(string: "home://home")!) {
                                WidgetEventRow(event: event, showSubtitle: true)
                            }
                            if event.kind == .task {
                                WidgetCompleteButton(event: event)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Meals

    private var mealsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetSectionHeader(systemImage: "fork.knife", title: "Menú")
            if snapshot.lunch.isEmpty && snapshot.dinner.isEmpty {
                Text("Sin comidas")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.inkSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if !snapshot.lunch.isEmpty {
                        WidgetMealDetail(meal: snapshot.lunch)
                    }
                    if !snapshot.dinner.isEmpty {
                        WidgetMealDetail(meal: snapshot.dinner)
                    }
                }
            }
        }
    }
}
