#if os(macOS)
import Foundation

enum SidebarModel {
    /// HIG: window titles stay under 15 characters.
    static let maxTitleLength = 14

    static func petRows(_ pets: [Pet]) -> [Pet] {
        pets.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func title(for item: SidebarItem, pets: [Pet]) -> String {
        if let fixed = item.fixedTitle { return fixed }
        guard case .pet(let id) = item, let pet = pets.first(where: { $0.id == id }) else { return "Pets" }
        guard pet.name.count > maxTitleLength else { return pet.name }
        return pet.name.prefix(maxTitleLength - 1).trimmingCharacters(in: .whitespaces) + "…"
    }

    static func resolve(_ item: SidebarItem, pets: [Pet]) -> SidebarItem {
        guard case .pet(let id) = item else { return item }
        return pets.contains { $0.id == id } ? item : .today
    }

    static func item(for route: AppRoute, pets: [Pet]) -> SidebarItem {
        switch route.hubDestination?.appTab ?? route.tab {
        case .tasks:    .tasks
        case .shopping: .shopping
        case .stock:    .stock
        case .meals:    .meals
        case .budget:   .budget
        case .pets:     petRows(pets).first.map { .pet($0.id) } ?? .today
        case .home, .search, .menu: .today
        }
    }
}
#endif
