import SwiftUI

// Card layout is a device-level UI preference, not shared domain data, so it is
// persisted locally (app-group UserDefaults, see DashboardConfigStore) and does
// NOT flow through the offline-first sync / outbox path.

nonisolated enum DashboardCard: String, CaseIterable, Codable, Identifiable, Sendable {
    case upcomingTasks, shoppingList, weekMeals, appointments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcomingTasks: "Upcoming Tasks"
        case .shoppingList:  "Shopping List"
        case .weekMeals:     "This Week's Meals"
        case .appointments:  "Upcoming Appointments"
        }
    }

    var systemImage: String {
        switch self {
        case .upcomingTasks: "checklist"
        case .shoppingList:  "cart.fill"
        case .weekMeals:     "fork.knife"
        case .appointments:  "calendar"
        }
    }

    // home:// host this card opens on tap. nil = the card acts in-place on Home
    // (Upcoming Tasks rows open the task sheet instead of navigating away).
    var deepLinkHost: String? {
        switch self {
        case .upcomingTasks: nil
        case .shoppingList:  "shopping"
        case .weekMeals:     "meals"
        case .appointments:  "pets"
        }
    }
}

nonisolated struct DashboardConfig: Codable, Equatable, Sendable {
    // Ordered list of ENABLED cards; order is display order. A card absent from
    // this array is disabled.
    var cards: [DashboardCard]

    static let `default` = DashboardConfig(cards: DashboardCard.allCases)

    var disabledCards: [DashboardCard] {
        DashboardCard.allCases.filter { !cards.contains($0) }
    }

    mutating func setEnabled(_ card: DashboardCard, _ enabled: Bool) {
        if enabled {
            guard !cards.contains(card) else { return }
            cards.append(card)
        } else {
            cards.removeAll { $0 == card }
        }
    }

    mutating func move(fromOffsets: IndexSet, toOffset: Int) {
        cards.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
}
