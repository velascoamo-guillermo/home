#if os(macOS)
struct TaskSectionGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let tasks: [HouseholdTask]
}
#endif
