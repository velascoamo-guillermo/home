import Foundation

struct AgendaGroup: Identifiable, Hashable {
    let section: AgendaSection
    let items: [AgendaItem]

    var id: AgendaSection { section }
}

struct AgendaDay: Hashable {
    let date: Date
    let groups: [AgendaGroup]

    var isEmpty: Bool { groups.isEmpty }

    func items(in section: AgendaSection) -> [AgendaItem] {
        groups.first { $0.section == section }?.items ?? []
    }
}
