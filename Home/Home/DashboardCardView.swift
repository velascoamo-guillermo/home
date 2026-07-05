import SwiftUI

struct DashboardCardView: View {
    let card: DashboardCard
    let onSelectTask: (HouseholdTask) -> Void

    @Environment(SupabaseStore.self) private var store
    @Environment(\.openURL) private var openURL

    private var shopping: (items: [StockProduct], total: Int) {
        DashboardData.shoppingList(stock: store.stockProducts, limit: DashboardData.shoppingLimit)
    }

    var body: some View {
        PressableGlassCard(onTap: navigate) {
            header
            content
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            IconChip(systemImage: card.systemImage, tint: card.tint)
            Text(card.title).font(.headline)
            Spacer()
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
            let result = DashboardData.upcomingTasks(
                tasks: store.householdTasks, events: store.events, pets: store.pets,
                today: .now, limit: DashboardData.taskLimit)
            if result.items.isEmpty {
                emptyState("Nothing scheduled")
            } else {
                VStack(spacing: 0) {
                    ForEach(result.items) { item in
                        HomeItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if case .task(let t) = item { onSelectTask(t) }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.spring(duration: 0.35), value: result.items.map(\.id))
                overflowFooter(shown: result.items.count, total: result.total)
            }

        case .shoppingList:
            if shopping.items.isEmpty {
                emptyState("Nothing to buy")
            } else {
                ForEach(shopping.items) { StockProductRow(product: $0, showsIcon: false) }
                overflowFooter(shown: shopping.items.count, total: shopping.total)
            }

        case .weekMeals:
            let result = DashboardData.weekMeals(
                meals: store.meals,
                todayWeekday: Self.currentWeekday(),
                limit: DashboardData.mealLimit)
            if result.items.isEmpty {
                emptyState("No meals planned")
            } else {
                ForEach(result.items) { SearchMealRow(meal: $0, showsIcon: false) }
                overflowFooter(shown: result.items.count, total: result.total)
            }

        case .appointments:
            let result = DashboardData.upcomingAppointments(
                appointments: store.appointments, pets: store.pets,
                limit: DashboardData.appointmentLimit)
            if result.items.isEmpty {
                emptyState("No upcoming appointments")
            } else {
                ForEach(result.items) { HomeItemRow(item: $0) }
                overflowFooter(shown: result.items.count, total: result.total)
            }
        }
    }

    @ViewBuilder
    private func overflowFooter(shown: Int, total: Int) -> some View {
        if total > shown {
            Text("+\(total - shown) more")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .contentTransition(.numericText())
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
