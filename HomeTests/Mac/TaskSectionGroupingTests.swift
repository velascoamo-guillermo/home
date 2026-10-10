#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("TaskSectionGrouping") @MainActor struct TaskSectionGroupingTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func day(_ offset: Int) -> Date { now.addingTimeInterval(Double(offset) * 86_400) }

    @Test("predefined sections follow their fixed order and empty ones are omitted")
    func predefinedOrder() {
        let garden = HouseholdTask(title: "Mow", section: .garden, intervalDays: 14, nextDueDate: day(1))
        let kitchen = HouseholdTask(title: "Descale", section: .kitchen, intervalDays: 30, nextDueDate: day(2))
        let groups = TaskSectionGrouping.groups([garden, kitchen], customSections: [])
        #expect(groups.map(\.title) == ["Kitchen", "Garden"])
    }

    @Test("a custom section wins over the predefined one and custom groups come last, by name")
    func customSections() {
        let boat = TaskSection(id: UUID(), name: "Boat")
        let attic = TaskSection(id: UUID(), name: "Attic")
        var oars = HouseholdTask(title: "Oil oars", intervalDays: 90, nextDueDate: day(3))
        oars.sectionId = boat.id
        var beams = HouseholdTask(title: "Check beams", intervalDays: 365, nextDueDate: day(4))
        beams.sectionId = attic.id
        let general = HouseholdTask(title: "Smoke alarm", intervalDays: 180, nextDueDate: day(5))
        let groups = TaskSectionGrouping.groups([oars, beams, general], customSections: [boat, attic])
        #expect(groups.map(\.title) == ["General", "Attic", "Boat"])
    }

    @Test("a task whose custom section was deleted falls back to its predefined section")
    func orphanedCustom() {
        var task = HouseholdTask(title: "Bleed radiators", section: .climate, intervalDays: 365, nextDueDate: day(1))
        task.sectionId = UUID()
        #expect(TaskSectionGrouping.groups([task], customSections: []).map(\.title) == ["Climate"])
    }

    @Test("tasks in a section sort by due date, then title")
    func taskOrder() {
        let b = HouseholdTask(title: "B", intervalDays: 7, nextDueDate: day(2))
        let a = HouseholdTask(title: "A", intervalDays: 7, nextDueDate: day(2))
        let first = HouseholdTask(title: "Z", intervalDays: 7, nextDueDate: day(1))
        let group = TaskSectionGrouping.groups([b, a, first], customSections: [])
        #expect(group.first?.tasks.map(\.title) == ["Z", "A", "B"])
    }
}
#endif
