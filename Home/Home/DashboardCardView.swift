import SwiftUI

struct DashboardCardView: View {
    let card: DashboardCard
    let onSelectTask: (HouseholdTask) -> Void

    @Environment(SupabaseStore.self) private var store
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
        }
        .padding(16)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
        .onTapGesture { navigate() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: card.systemImage)
                .font(.headline)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(card.title).font(.headline)
            Spacer()
            if let count = headerCount {
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if card.deepLinkHost != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch card {
        case .upcomingTasks:
            let items = DashboardData.upcomingTasks(
                tasks: store.householdTasks, events: store.events, pets: store.pets,
                today: .now, limit: DashboardData.taskLimit)
            if items.isEmpty {
                emptyState("Nothing scheduled")
            } else {
                ForEach(items) { item in
                    HomeItemRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if case .task(let t) = item { onSelectTask(t) }
                        }
                }
            }

        case .shoppingList:
            let r = DashboardData.shoppingList(stock: store.stockProducts, limit: DashboardData.shoppingLimit)
            if r.items.isEmpty {
                emptyState("Nothing to buy")
            } else {
                ForEach(r.items) { StockProductRow(product: $0) }
            }

        case .weekMeals:
            let meals = DashboardData.weekMeals(
                meals: store.meals,
                todayWeekday: Self.currentWeekday(),
                limit: DashboardData.mealLimit)
            if meals.isEmpty {
                emptyState("No meals planned")
            } else {
                ForEach(meals) { SearchMealRow(meal: $0) }
            }

        case .appointments:
            let items = DashboardData.upcomingAppointments(
                appointments: store.appointments, pets: store.pets,
                limit: DashboardData.appointmentLimit)
            if items.isEmpty {
                emptyState("No upcoming appointments")
            } else {
                ForEach(items) { HomeItemRow(item: $0) }
            }
        }
    }

    private var headerCount: Int? {
        switch card {
        case .shoppingList:
            DashboardData.shoppingList(stock: store.stockProducts, limit: DashboardData.shoppingLimit).total
        default:
            nil
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private func navigate() {
        guard let host = card.deepLinkHost, let url = URL(string: "home://\(host)") else { return }
        openURL(url)
    }

    private static func currentWeekday() -> Int {
        // Calendar weekday: 1=Sun…7=Sat. Map to Weekday rawValue: 1=Mon…7=Sun.
        let c = Calendar.current.component(.weekday, from: .now)
        return c == 1 ? 7 : c - 1
    }
}
