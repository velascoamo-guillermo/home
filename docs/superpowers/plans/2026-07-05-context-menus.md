# Context Menus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace swipe/drag row actions across every list screen with long-press context menus that use nested submenus for grouped options.

**Architecture:** Reusable `View` structs (one per multi-action entity) in `Home/Shared/ContextMenus/`, each reading `@Environment(SupabaseStore.self)` and firing `Task { await store… }` directly. Attached with `.contextMenu { … }`. Single-delete rows use an inline `.contextMenu`. Calendar reminder offsets and multi-day snooze are new pure helpers with unit tests.

**Tech Stack:** SwiftUI, Swift 6 strict concurrency, EventKit, Swift Testing (`HomeTests`).

## Global Constraints

- `SWIFT_VERSION = 6.0`; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. All new code compiles clean — zero concurrency errors/warnings.
- No `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency`, or `Task.detached` without a documented reason.
- No third-party dependencies except the Supabase Swift SDK.
- Each Swift file has one primary type. No comments unless the WHY is non-obvious.
- Icon-only buttons need `.accessibilityLabel`; decorative images `.accessibilityHidden(true)`. (Context-menu items carry labels via `Label` — no new icon-only buttons introduced.)
- Use `.tint` for the app tint; `.clipShape(.rect(cornerRadius:))` form.
- Build: Xcode `Cmd+B` (zero errors). Test: `Cmd+U`. CLI equivalents below use `xcodebuild`; if unavailable, verify manually in Xcode.
  - Build: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5` → `** BUILD SUCCEEDED **`
  - Test: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:HomeTests/<Suite> 2>&1 | tail -15` → `** TEST SUCCEEDED **`

## Section-move model (important)

A task's section is stored as **two** fields: `task.icon` (section icon) + `task.sectionId` (UUID for custom sections, `nil` for predefined). There is no distinct "None" state — predefined sections are `icon` + `sectionId == nil`. The Section submenu therefore lists Predefined + Custom (no "None"), and each item sets **both** `icon` and `sectionId`. This matches the existing `TaskSectionPicker`.

## File Structure

**Create:**
- `Home/Shared/ContextMenus/TaskContextMenu.swift` — task menu (Done, Snooze›, Section›, Calendar›, Delete)
- `Home/Shared/ContextMenus/EventContextMenu.swift` — pet-event menu (Calendar›, Delete)
- `Home/Shared/ContextMenus/AppointmentContextMenu.swift` — appointment menu (status-aware)
- `Home/Shared/ContextMenus/StockContextMenu.swift` — stock menu (Adjust›, Delete)
- `HomeTests/CalendarReminderTests.swift`
- `HomeTests/HouseholdTaskSnoozeTests.swift`

**Modify:**
- `Home/Shared/Services/CalendarService.swift` — add `ReminderOffset`, `reminder:` param
- `Home/Home/HouseholdTask.swift` — add `snoozed(byDays:)`
- `Home/Home/TasksView.swift` — swipe → contextMenu (task/event/appointment)
- `Home/Stock/StockView.swift` — swipe → contextMenu
- `Home/Pets/Detail/Tabs/AppointmentsTabView.swift` — swipe → contextMenu
- `Home/Pets/Detail/Tabs/EventsTabView.swift` — swipe → contextMenu
- `Home/Pets/PetsView.swift` — swipe → inline delete contextMenu
- `Home/Pets/Detail/Tabs/VetTabView.swift` — swipe → inline delete contextMenu
- `Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift` — swipe → inline delete contextMenu
- `Home/Menu/MealSlotRow.swift` — swipe → inline cook contextMenu
- `Home/Search/SearchView.swift` — reuse shared menus, drop `stockMenu`/`taskMenu` helpers

---

### Task 1: CalendarService reminder offsets

**Files:**
- Modify: `Home/Shared/Services/CalendarService.swift`
- Test: `HomeTests/CalendarReminderTests.swift`

**Interfaces:**
- Produces: `CalendarService.ReminderOffset` (`.atTime`, `.oneHourBefore`, `.oneDayBefore`; `CaseIterable`) with `var label: String` and `var relativeOffset: TimeInterval`. New optional `reminder: ReminderOffset? = nil` param on `addHouseholdTask`, `addAppointment`, `addPetEvent`.

- [ ] **Step 1: Write the failing test**

Create `HomeTests/CalendarReminderTests.swift`:

```swift
import Testing
import Foundation
@testable import Casita

@Suite struct CalendarReminderTests {
    @Test func offsetSecondsPerCase() {
        #expect(CalendarService.ReminderOffset.atTime.relativeOffset == 0)
        #expect(CalendarService.ReminderOffset.oneHourBefore.relativeOffset == -3600)
        #expect(CalendarService.ReminderOffset.oneDayBefore.relativeOffset == -86400)
    }

    @Test func allCasesHaveLabels() {
        for offset in CalendarService.ReminderOffset.allCases {
            #expect(!offset.label.isEmpty)
        }
    }
}
```

- [ ] **Step 2: Run test — verify it fails**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:HomeTests/CalendarReminderTests 2>&1 | tail -15`
Expected: FAIL — `ReminderOffset` not a member of `CalendarService`.

- [ ] **Step 3: Add the enum**

In `Home/Shared/Services/CalendarService.swift`, inside `enum CalendarService`, after `private static let store`, add:

```swift
    enum ReminderOffset: CaseIterable {
        case atTime, oneHourBefore, oneDayBefore

        var label: String {
            switch self {
            case .atTime:        return "At time"
            case .oneHourBefore: return "1 hour before"
            case .oneDayBefore:  return "1 day before"
            }
        }

        var relativeOffset: TimeInterval {
            switch self {
            case .atTime:        return 0
            case .oneHourBefore: return -3600
            case .oneDayBefore:  return -86400
            }
        }
    }
```

- [ ] **Step 4: Add `reminder:` param to the three add methods**

Change each signature and add the alarm line before `store.save`.

`addAppointment`:
```swift
    @discardableResult
    static func addAppointment(_ appt: Appointment, petName: String, reminder: ReminderOffset? = nil) async -> Bool {
        guard await requestAccess() else { return false }
        let event = EKEvent(eventStore: store)
        event.title = "\(petName) — \(appt.reason)"
        event.startDate = appt.date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: appt.date) ?? appt.date
        event.notes = appt.notes.isEmpty ? nil : appt.notes
        event.calendar = store.defaultCalendarForNewEvents
        if let reminder { event.addAlarm(EKAlarm(relativeOffset: reminder.relativeOffset)) }
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
```

`addPetEvent` — add `, reminder: ReminderOffset? = nil` to the signature and, before `do {`:
```swift
        if let reminder { event.addAlarm(EKAlarm(relativeOffset: reminder.relativeOffset)) }
```

`addHouseholdTask` — add `, reminder: ReminderOffset? = nil` to the signature and, before `do {`:
```swift
        if let reminder { event.addAlarm(EKAlarm(relativeOffset: reminder.relativeOffset)) }
```

(The default `nil` keeps `AppointmentsTabView`/`EventsTabView`/`SearchView` existing callers compiling unchanged.)

- [ ] **Step 5: Run test — verify it passes**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:HomeTests/CalendarReminderTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Home/Shared/Services/CalendarService.swift HomeTests/CalendarReminderTests.swift
git commit -m "feat: add reminder offsets to CalendarService"
```

---

### Task 2: HouseholdTask multi-day snooze

**Files:**
- Modify: `Home/Home/HouseholdTask.swift`
- Test: `HomeTests/HouseholdTaskSnoozeTests.swift`

**Interfaces:**
- Produces: `func snoozed(byDays days: Int) -> HouseholdTask`. `snoozedByOneDay()` is retained, delegating to `snoozed(byDays: 1)`.

- [ ] **Step 1: Write the failing test**

Create `HomeTests/HouseholdTaskSnoozeTests.swift`:

```swift
import Testing
import Foundation
@testable import Casita

@Suite struct HouseholdTaskSnoozeTests {
    private func makeTask(due: Date) -> HouseholdTask {
        HouseholdTask(title: "x", icon: "wrench", intervalDays: 7, nextDueDate: due)
    }

    @Test func snoozeAddsGivenDays() {
        let base = Calendar.current.startOfDay(for: .now)
        let task = makeTask(due: base)
        let expected = Calendar.current.date(byAdding: .day, value: 3, to: base)
        #expect(task.snoozed(byDays: 3).nextDueDate == expected)
    }

    @Test func oneDayHelperMatchesGeneric() {
        let base = Calendar.current.startOfDay(for: .now)
        let task = makeTask(due: base)
        #expect(task.snoozedByOneDay().nextDueDate == task.snoozed(byDays: 1).nextDueDate)
    }
}
```

- [ ] **Step 2: Run test — verify it fails**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:HomeTests/HouseholdTaskSnoozeTests 2>&1 | tail -15`
Expected: FAIL — `snoozed(byDays:)` not found.

- [ ] **Step 3: Add the method, refactor `snoozedByOneDay`**

In `Home/Home/HouseholdTask.swift`, replace the existing `snoozedByOneDay()` method with:

```swift
    func snoozed(byDays days: Int) -> HouseholdTask {
        var copy = self
        copy.nextDueDate = Calendar.current.date(
            byAdding: .day, value: days, to: nextDueDate
        ) ?? nextDueDate
        return copy
    }

    func snoozedByOneDay() -> HouseholdTask { snoozed(byDays: 1) }
```

- [ ] **Step 4: Run test — verify it passes**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:HomeTests/HouseholdTaskSnoozeTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Home/Home/HouseholdTask.swift HomeTests/HouseholdTaskSnoozeTests.swift
git commit -m "feat: add multi-day snooze to HouseholdTask"
```

---

### Task 3: Shared context-menu components

**Files:**
- Create: `Home/Shared/ContextMenus/TaskContextMenu.swift`
- Create: `Home/Shared/ContextMenus/EventContextMenu.swift`
- Create: `Home/Shared/ContextMenus/AppointmentContextMenu.swift`
- Create: `Home/Shared/ContextMenus/StockContextMenu.swift`

**Interfaces:**
- Consumes: `CalendarService.ReminderOffset` (Task 1), `HouseholdTask.snoozed(byDays:)` (Task 2), `SupabaseStore.CompletionResult`, store methods `completeTask/updateTask/deleteTask/updateProduct/replenish/deleteProduct/updateAppointmentStatus/deleteAppointment/deleteEvent`, `StockProduct.consuming(units:)/emptied()`, `TaskSection.Predefined`, `store.customSections`.
- Produces:
  - `TaskContextMenu(task: HouseholdTask, onCompleted: ((SupabaseStore.CompletionResult) -> Void)? = nil)`
  - `EventContextMenu(event: PetEvent, petName: String)`
  - `AppointmentContextMenu(appointment: Appointment, petName: String)`
  - `StockContextMenu(product: StockProduct)`

> Note: new files must be added to the `Home` target in Xcode. With the CLI, add them to the file-system group so the project's synchronized group picks them up; if the project uses explicit membership, open Xcode once to confirm target membership before building.

- [ ] **Step 1: Create `TaskContextMenu.swift`**

```swift
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
                move(name: section.name, icon: section.icon, sectionId: nil)
            }
            if !store.customSections.isEmpty {
                Divider()
                ForEach(store.customSections) { section in
                    move(name: section.name, icon: section.icon, sectionId: section.id)
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

    private func move(name: String, icon: String, sectionId: UUID?) -> some View {
        Button {
            var updated = task
            updated.icon = icon
            updated.sectionId = sectionId
            Task { try? await store.updateTask(updated) }
        } label: { Label(name, systemImage: icon) }
    }
}
```

- [ ] **Step 2: Create `EventContextMenu.swift`**

```swift
import SwiftUI

struct EventContextMenu: View {
    let event: PetEvent
    let petName: String

    @Environment(SupabaseStore.self) private var store

    var body: some View {
        Menu {
            ForEach(CalendarService.ReminderOffset.allCases, id: \.self) { offset in
                Button(offset.label) {
                    Task { await CalendarService.addPetEvent(event, petName: petName, reminder: offset) }
                }
            }
        } label: { Label("Add to calendar", systemImage: "calendar.badge.plus") }

        Button(role: .destructive) {
            Task { try? await store.deleteEvent(event) }
        } label: { Label("Delete", systemImage: "trash") }
    }
}
```

- [ ] **Step 3: Create `AppointmentContextMenu.swift`**

```swift
import SwiftUI

struct AppointmentContextMenu: View {
    let appointment: Appointment
    let petName: String

    @Environment(SupabaseStore.self) private var store

    var body: some View {
        if appointment.status == .upcoming {
            Button {
                Task { try? await store.updateAppointmentStatus(appointment, status: .done) }
            } label: { Label("Done", systemImage: "checkmark") }

            Menu {
                ForEach(CalendarService.ReminderOffset.allCases, id: \.self) { offset in
                    Button(offset.label) {
                        Task { await CalendarService.addAppointment(appointment, petName: petName, reminder: offset) }
                    }
                }
            } label: { Label("Add to calendar", systemImage: "calendar.badge.plus") }

            Button(role: .destructive) {
                Task { try? await store.updateAppointmentStatus(appointment, status: .cancelled) }
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        } else {
            Button(role: .destructive) {
                Task { try? await store.deleteAppointment(appointment) }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
```

- [ ] **Step 4: Create `StockContextMenu.swift`**

```swift
import SwiftUI

struct StockContextMenu: View {
    let product: StockProduct

    @Environment(SupabaseStore.self) private var store

    var body: some View {
        Menu {
            Button {
                Task { try? await store.replenish(product) }
            } label: { Label("Replenish", systemImage: "plus.square.on.square") }

            consume(units: 1, title: "Consume 1")
            consume(units: 2, title: "Consume 2")
            consume(units: 5, title: "Consume 5")

            Button {
                Task { try? await store.updateProduct(product.emptied()) }
            } label: { Label("Empty", systemImage: "trash.slash") }
        } label: { Label("Adjust stock", systemImage: "slider.horizontal.3") }

        Button(role: .destructive) {
            Task { try? await store.deleteProduct(product) }
        } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private func consume(units: Int, title: String) -> some View {
        if let consumed = product.consuming(units: units) {
            Button {
                Task { try? await store.updateProduct(consumed) }
            } label: { Label(title, systemImage: "minus.circle") }
        }
    }
}
```

- [ ] **Step 5: Build — verify it compiles**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Home/Shared/ContextMenus/
git commit -m "feat: add reusable context-menu components"
```

---

### Task 4: Wire TasksView to context menus

**Files:**
- Modify: `Home/Home/TasksView.swift`

**Interfaces:**
- Consumes: `TaskContextMenu`, `EventContextMenu`, `AppointmentContextMenu` (Task 3).

- [ ] **Step 1: Replace the swipe actions with a context menu**

In `Home/Home/TasksView.swift`, replace the entire `.swipeActions(edge: .leading) { … }` and `.swipeActions(edge: .trailing) { … }` chain on `HomeItemRow` (currently lines 31–70) with a single `.contextMenu`. The row becomes:

```swift
                        HomeItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { handleTap(item) }
                            .glassRow()
                            .contextMenu {
                                switch item {
                                case .task(let t):
                                    TaskContextMenu(task: t) { result in
                                        if case .outOfStock(let product) = result {
                                            outOfStock = OutOfStockInfo(
                                                product: product,
                                                needed: t.quantityPerCompletion
                                            )
                                        }
                                    }
                                case .event(let e, let pet):
                                    EventContextMenu(event: e, petName: pet.name)
                                case .appointment(let a, let pet):
                                    AppointmentContextMenu(appointment: a, petName: pet.name)
                                }
                            }
```

- [ ] **Step 2: Delete the now-unused helpers**

In the same file, delete the `markDone(_:)` method (lines ~113–120) and the `snooze(_:)` method (lines ~122–124). Keep `handleTap`, `OutOfStockInfo`, and the out-of-stock `.alert`.

- [ ] **Step 3: Build — verify it compiles**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **` (no "unused"/"not found" errors; `markDone`/`snooze` removal is clean).

- [ ] **Step 4: Commit**

```bash
git add Home/Home/TasksView.swift
git commit -m "feat: use context menus in TasksView"
```

---

### Task 5: Wire StockView to context menu

**Files:**
- Modify: `Home/Stock/StockView.swift`

**Interfaces:**
- Consumes: `StockContextMenu` (Task 3).

- [ ] **Step 1: Replace the swipe actions with a context menu**

In `Home/Stock/StockView.swift`, replace the `.swipeActions(edge: .leading) { … }` and `.swipeActions(edge: .trailing) { … }` chain on the product `Button` (currently lines 24–40) with:

```swift
                        .glassRow()
                        .contextMenu { StockContextMenu(product: product) }
```

(Keep the `.buttonStyle(.plain)` above it; `.glassRow()` already existed — do not duplicate it.)

- [ ] **Step 2: Build — verify it compiles**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Home/Stock/StockView.swift
git commit -m "feat: use context menu in StockView"
```

---

### Task 6: Wire AppointmentsTabView to context menu

**Files:**
- Modify: `Home/Pets/Detail/Tabs/AppointmentsTabView.swift`

**Interfaces:**
- Consumes: `AppointmentContextMenu` (Task 3). The menu is status-aware, so the same call works for upcoming and past rows.

- [ ] **Step 1: Replace swipe actions on the upcoming rows**

In the `Section("Upcoming")` `ForEach`, replace the `.swipeActions(edge: .leading) { … }` and `.swipeActions(edge: .trailing) { … }` chain on `AppointmentRow` with:

```swift
                        AppointmentRow(appointment: appt)
                            .contextMenu {
                                AppointmentContextMenu(appointment: appt, petName: pet.name)
                            }
```

- [ ] **Step 2: Replace swipe actions on the past rows**

In the `Section("Past")` `ForEach`, replace the `.swipeActions { … }` chain on `AppointmentRow` with:

```swift
                        AppointmentRow(appointment: appt)
                            .contextMenu {
                                AppointmentContextMenu(appointment: appt, petName: pet.name)
                            }
```

- [ ] **Step 3: Build — verify it compiles**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Home/Pets/Detail/Tabs/AppointmentsTabView.swift
git commit -m "feat: use context menu in AppointmentsTabView"
```

---

### Task 7: Wire EventsTabView to context menu

**Files:**
- Modify: `Home/Pets/Detail/Tabs/EventsTabView.swift`

**Interfaces:**
- Consumes: `EventContextMenu` (Task 3).

- [ ] **Step 1: Replace the swipe actions with a context menu**

In the `ForEach(events)`, replace the `.swipeActions(edge: .leading) { … }` and `.swipeActions(edge: .trailing) { … }` chain on the event `Button` with:

```swift
                Button { selectedEvent = event } label: { EventRow(event: event) }
                    .buttonStyle(.plain)
                    .contextMenu { EventContextMenu(event: event, petName: pet.name) }
```

- [ ] **Step 2: Build — verify it compiles**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Home/Pets/Detail/Tabs/EventsTabView.swift
git commit -m "feat: use context menu in EventsTabView"
```

---

### Task 8: Inline delete/cook menus (Pets, Vet, Clinical, Meal)

**Files:**
- Modify: `Home/Pets/PetsView.swift`
- Modify: `Home/Pets/Detail/Tabs/VetTabView.swift`
- Modify: `Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift`
- Modify: `Home/Menu/MealSlotRow.swift`

**Interfaces:**
- Consumes: store methods `deletePet/deleteVet/deleteClinicalEntry` and `MealSlotRow.onCook`. No new types.

- [ ] **Step 1: PetsView**

Replace the `.swipeActions(edge: .trailing) { … }` on the `NavigationLink` with:

```swift
            .contextMenu {
                Button(role: .destructive) {
                    Task { try? await store.deletePet(pet) }
                } label: { Label("Delete", systemImage: "trash") }
            }
```

- [ ] **Step 2: VetTabView**

Replace the `.swipeActions(edge: .trailing) { … }` on `VetRow` with:

```swift
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { try? await store.deleteVet(vet) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
```

- [ ] **Step 3: ClinicalHistoryTabView**

Replace the `.swipeActions { … }` on the entry `Button` with:

```swift
                .contextMenu {
                    Button(role: .destructive) {
                        Task { try? await store.deleteClinicalEntry(entry) }
                    } label: { Label("Delete", systemImage: "trash") }
                }
```

- [ ] **Step 4: MealSlotRow**

Replace the `.swipeActions(edge: .leading) { … }` on the populated-entry `HStack` with:

```swift
            .contextMenu {
                Button { onCook() } label: {
                    Label("Cocinado", systemImage: "flame.fill")
                }
            }
```

- [ ] **Step 5: Build — verify it compiles**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Home/Pets/PetsView.swift Home/Pets/Detail/Tabs/VetTabView.swift Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift Home/Menu/MealSlotRow.swift
git commit -m "feat: use context menus for delete/cook rows"
```

---

### Task 9: Refactor SearchView to shared menus

**Files:**
- Modify: `Home/Search/SearchView.swift`

**Interfaces:**
- Consumes: `StockContextMenu`, `TaskContextMenu` (Task 3). `mealMenu`/`petMenu` remain private inline helpers.

- [ ] **Step 1: Swap the stock + task menu call sites**

In the `Section("Stock")` `ForEach`, change `.contextMenu { stockMenu(product) }` to:

```swift
                                    .contextMenu { StockContextMenu(product: product) }
```

In the `Section("Tasks")` `ForEach`, change `.contextMenu { taskMenu(task) }` to:

```swift
                                    .contextMenu { TaskContextMenu(task: task) }
```

(No `onCompleted` here — silent complete, matching current SearchView behavior which ignores the result.)

- [ ] **Step 2: Delete the now-unused private helpers**

Delete the `private func stockMenu(_:)` and `private func taskMenu(_:)` methods entirely. Keep `mealMenu(_:)` and `petMenu(_:)`.

- [ ] **Step 3: Build — verify it compiles**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **` (no "unused function" — they are removed; no "not found" — shared views exist from Task 3).

- [ ] **Step 4: Full test suite + commit**

Run: `xcodebuild -project Home.xcodeproj -scheme Home -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`

```bash
git add Home/Search/SearchView.swift
git commit -m "refactor: reuse shared context menus in SearchView"
```

---

## Manual verification (after all tasks)

Run the app in the simulator and confirm on each screen: long-press opens the menu; tap still edits/opens detail; no swipe actions remain. Specifically verify Tasks (Snooze›, Section›, Calendar› submenus; out-of-stock alert still fires on Done when stock is short), Stock (Adjust stock› with consume options hidden when stock too low), Appointments (Done/Cancel/Calendar on upcoming, Delete on past). Use argent MCP tools per the argent rule for on-device checks.
