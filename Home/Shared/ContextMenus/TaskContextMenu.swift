import SwiftUI

struct TaskContextMenu: View {
    let task: HouseholdTask
    var onCompleted: ((SupabaseStore.CompletionResult) -> Void)? = nil

    @Environment(SupabaseStore.self) private var store

    var body: some View {
        Button {
            Task {
                if let result = try? await store.completeTask(task) {
                    onCompleted?(result)
                }
            }
        } label: { Label("Done", systemImage: "checkmark") }

        Menu {
            snooze(days: 1,  title: "1 day")
            snooze(days: 3,  title: "3 days")
            snooze(days: 7,  title: "1 week")
            snooze(days: 14, title: "2 weeks")
        } label: { Label("Snooze", systemImage: "clock.arrow.circlepath") }

        Menu {
            ForEach(TaskSection.Predefined.allCases, id: \.self) { section in
                movePredefined(section)
            }
            if !store.customSections.isEmpty {
                Divider()
                ForEach(store.customSections) { section in
                    moveCustom(section)
                }
            }
        } label: { Label("Section", systemImage: "folder") }

        Menu {
            ForEach(CalendarService.ReminderOffset.allCases, id: \.self) { offset in
                Button(offset.label) {
                    Task { await CalendarService.addHouseholdTask(task, reminder: offset) }
                }
            }
        } label: { Label("Add to calendar", systemImage: "calendar.badge.plus") }

        Button(role: .destructive) {
            Task { try? await store.deleteTask(task) }
        } label: { Label("Delete", systemImage: "trash") }
    }

    private func snooze(days: Int, title: String) -> some View {
        Button(title) {
            Task { try? await store.updateTask(task.snoozed(byDays: days)) }
        }
    }

    private func movePredefined(_ section: TaskSection.Predefined) -> some View {
        Button(section.name) {
            var updated = task
            updated.section = section
            updated.sectionId = nil
            Task { try? await store.updateTask(updated) }
        }
    }

    private func moveCustom(_ section: TaskSection) -> some View {
        Button(section.name) {
            var updated = task
            updated.sectionId = section.id
            Task { try? await store.updateTask(updated) }
        }
    }
}
