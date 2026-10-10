#if os(macOS)
import Foundation

enum TaskSectionGrouping {
    static func groups(_ tasks: [HouseholdTask], customSections: [TaskSection]) -> [TaskSectionGroup] {
        let customIDs = Set(customSections.map(\.id))
        let byKey = Dictionary(grouping: tasks) { task -> String in
            if let id = task.sectionId, customIDs.contains(id) { return "custom-\(id)" }
            return "predefined-\(task.section.rawValue)"
        }
        let predefined = TaskSection.Predefined.allCases.compactMap { section -> TaskSectionGroup? in
            let key = "predefined-\(section.rawValue)"
            guard let items = byKey[key] else { return nil }
            return TaskSectionGroup(id: key, title: section.name, tasks: sorted(items))
        }
        let custom = customSections
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .compactMap { section -> TaskSectionGroup? in
                let key = "custom-\(section.id)"
                guard let items = byKey[key] else { return nil }
                return TaskSectionGroup(id: key, title: section.name, tasks: sorted(items))
            }
        return predefined + custom
    }

    private static func sorted(_ tasks: [HouseholdTask]) -> [HouseholdTask] {
        tasks.sorted { ($0.nextDueDate, $0.title) < ($1.nextDueDate, $1.title) }
    }
}
#endif
