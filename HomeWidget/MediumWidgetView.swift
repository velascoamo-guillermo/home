import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            WidgetCard(fill: Palette.tasks) { eventsContent }
                .frame(maxHeight: .infinity)
            Link(destination: URL(string: "home://meals")!) {
                WidgetCard(fill: Palette.meals) { mealsContent }
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(12)
    }

    private var eventsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: "home://home")!) {
                WidgetSectionHeader(systemImage: "checklist", title: "Hoy")
            }
            if snapshot.events.isEmpty {
                Link(destination: URL(string: "home://home")!) {
                    Text("Nada para hoy")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(snapshot.events) { event in
                        HStack(spacing: 6) {
                            Link(destination: URL(string: "home://home")!) {
                                WidgetEventRow(event: event)
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

    private var mealsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetSectionHeader(systemImage: "fork.knife", title: "Menú")
            VStack(alignment: .leading, spacing: 0) {
                WidgetMealTitle(meal: snapshot.lunch)
                    .frame(maxHeight: .infinity, alignment: .leading)
                WidgetMealTitle(meal: snapshot.dinner)
                    .frame(maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
    }
}
