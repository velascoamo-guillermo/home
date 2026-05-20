# Home Timeline — Design Spec

**Date:** 2026-05-20  
**Status:** Approved

## Overview

Replace the placeholder `HomeView` with a unified timeline feed showing upcoming pet appointments and periodical household tasks, sorted by due date.

---

## Data Models

### `HouseholdTask`

```swift
struct HouseholdTask: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var icon: String       // SF Symbol name
    var intervalDays: Int  // recurrence period in days
    var nextDueDate: Date
    var notes: String = ""

    enum CodingKeys: String, CodingKey {
        case id, title, icon, notes
        case intervalDays = "interval_days"
        case nextDueDate  = "next_due_date"
    }
}
```

### `HomeItem`

```swift
enum HomeItem: Identifiable {
    case appointment(Appointment, Pet)
    case task(HouseholdTask)

    var id: UUID {
        switch self {
        case .appointment(let a, _): return a.id
        case .task(let t):           return t.id
        }
    }

    var dueDate: Date {
        switch self {
        case .appointment(let a, _): return a.date
        case .task(let t):           return t.nextDueDate
        }
    }
}
```

### Supabase table: `household_tasks`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `title` | `text` | |
| `icon` | `text` | SF Symbol name |
| `interval_days` | `int` | recurrence period |
| `next_due_date` | `timestamptz` | |
| `notes` | `text` | default `''` |

---

## SupabaseStore Changes

### New stored property

```swift
var householdTasks: [HouseholdTask] = []
```

### Load in `loadAll()`

```swift
async let ht: [HouseholdTask] = client.from("household_tasks").select().execute().value
householdTasks = try await ht
```

### New CRUD methods

```swift
func addTask(_ task: HouseholdTask) async throws
func updateTask(_ task: HouseholdTask) async throws  // used for edit, mark done, snooze
func deleteTask(_ task: HouseholdTask) async throws
```

### Computed timeline

```swift
var homeTimeline: [HomeItem] {
    let appts = appointments
        .filter { $0.status == .upcoming }
        .compactMap { appt -> HomeItem? in
            guard let pet = pets.first(where: { $0.id == appt.petId }) else { return nil }
            return .appointment(appt, pet)
        }
    let tasks = householdTasks.map { HomeItem.task($0) }
    return (appts + tasks).sorted { $0.dueDate < $1.dueDate }
}
```

Only `.upcoming` appointments appear. All household tasks always appear; past-due ones render with an overdue badge.

---

## Mark Done

When user marks a task done:
1. `task.nextDueDate = Date.now + intervalDays days`
2. Call `updateTask(task)` — persists new due date to Supabase.

No "completed" state; the task recurs automatically.

## Snooze

Pushes `nextDueDate` forward by 1 day, then calls `updateTask`.

## Add to Calendar

Uses existing `CalendarService` to export `nextDueDate` as an event. Same pattern as appointments.

---

## HomeView UI

```
NavigationStack — title "Home"
  List
    ForEach(store.homeTimeline) { item in
      HomeItemRow(item)
        .swipeActions(edge: .leading)  → "Done" (tasks only, green)
        .swipeActions(edge: .trailing) → "Snooze" (tasks, orange) | "Delete" (tasks, red)
    }
  toolbar: (+) → AddHouseholdTaskSheet
```

Tapping a task row → `EditHouseholdTaskSheet` (pre-filled form).  
Tapping an appointment row → no-op or existing appointment detail (no change to Pets flow).

---

## HomeItemRow

Displays per item:

| Field | Appointment | Task |
|---|---|---|
| Icon | `calendar` | `task.icon` (SF Symbol) |
| Title | `appointment.reason` | `task.title` |
| Subtitle | Pet name | `task.notes` (if set) |
| Due label | Relative ("Today", "Tomorrow", "in N days") | Same |
| Overdue badge | — | Red badge if `nextDueDate < .now` |

Relative date logic:
- Same day → "Today"
- +1 day → "Tomorrow"
- 2–7 days → "in N days"
- Beyond → formatted date string

---

## AddHouseholdTaskSheet / EditHouseholdTaskSheet

Fields:
- Title (text field)
- Icon (curated SF Symbol picker, ~10 options: `wrench`, `drop`, `flame`, `fan`, `lightbulb`, `trash`, `shippingbox`, `lawn`, `hammer`, `air.purifier`)
- Interval picker (days / weeks / months → converts to `intervalDays`)
- First due date (DatePicker)
- Notes (optional text field)

Save → `addTask` or `updateTask`. Cancel dismisses without saving.

---

## Files to Create / Modify

| Action | File |
|---|---|
| Create | `Home/Home/Models/HouseholdTask.swift` |
| Create | `Home/Home/Models/HomeItem.swift` |
| Modify | `Home/Home/Shared/Services/SupabaseStore.swift` |
| Modify | `Home/Home/Home/HomeView.swift` |
| Create | `Home/Home/Home/HomeItemRow.swift` |
| Create | `Home/Home/Home/AddHouseholdTaskSheet.swift` |

---

## Out of Scope

- Push notifications for due tasks
- Custom snooze duration
- Task categories or priority
- Filtering/sorting controls in the feed
