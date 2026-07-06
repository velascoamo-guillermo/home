# Context Menus Replace Swipe Actions (App-Wide)

**Date:** 2026-07-05
**Status:** Approved — ready for implementation plan
**Branch base:** `feat/glass-design-system`

## Goal

Replace swipe/drag row actions across every list screen with long-press **context menus** that use **nested submenus** for grouped/quick options. Unify on the `.contextMenu` pattern already used by `SearchView` and `FilesTabView`.

## Interaction Model

- Every list row: long-press → context menu (`.contextMenu`). **Tap behavior unchanged** (edit sheet / open detail / select).
- All `.swipeActions` removed.
- Destructive actions keep `role: .destructive` (red). Delete stays immediate — no confirmation dialog (matches current behavior).
- Submenus are fixed-option only. No custom date/amount picker sheets (context menus cannot present sheets; keeping menus sheet-free is what makes them reusable across screens).

## Architecture

New folder `Home/Shared/ContextMenus/`. One `View` struct per multi-action entity. Each reads `@Environment(SupabaseStore.self)` and fires `Task { await store… }` directly. Attached with `.contextMenu { TaskContextMenu(task: t) }`.

Single-delete rows (Vet, Clinical entry, Pet, Meal) keep an inline `.contextMenu { Button(role: .destructive) … }` — a dedicated type per delete-only row is not warranted.

### Menu views (one primary type per file)

| File | Entity | Items |
|---|---|---|
| `TaskContextMenu.swift` | `HouseholdTask` | **Done** · **Snooze ›** (1 day / 3 days / 1 week / 2 weeks) · **Section ›** (None + predefined + custom) · **Add to calendar ›** (reminder offsets) · **Delete** (destructive) |
| `StockContextMenu.swift` | `StockProduct` | **Adjust stock ›** (Replenish +1 pack · Consume 1 · Consume 2 · Consume 5 · Empty) · **Delete** (destructive) |
| `AppointmentContextMenu.swift` | `Appointment` | upcoming: **Done** · **Cancel** (destructive) · **Add to calendar ›**  ·  past: **Delete** (destructive) |
| `EventContextMenu.swift` | `PetEvent` | **Add to calendar ›** (reminder offsets) · **Delete** (destructive) |

### Menu action mapping

- **Task Done** → `store.completeTask(task)`. See "Out-of-stock feedback" below.
- **Task Snooze** → `store.updateTask(task.snoozed(byDays: N))` for N ∈ {1, 3, 7, 14}.
- **Task Section** → set `task.sectionId` to the chosen section id (or `nil` for "None"), then `store.updateTask`. Submenu built from `TaskSection.Predefined` + `store.customSections`.
- **Task/Event/Appointment Calendar** → `CalendarService.add…(…, reminder: offset)` for each `ReminderOffset` case.
- **Stock Adjust**:
  - Replenish → `store.updateProduct(product.replenished())` (or existing `store.replenish(product)`).
  - Consume N → `store.updateProduct(product.consuming(units: N)!)`; item disabled when `product.totalUnits < N` (guard `consuming` returning `nil`).
  - Empty → `store.updateProduct(product.emptied())`.
- **Appointment Done / Cancel** → `store.updateAppointmentStatus(appt, status: .done / .cancelled)`.
- **Delete** → existing `store.delete…` per entity.

## Supporting Changes

### `CalendarService`

Add reminder support:

```swift
enum ReminderOffset: CaseIterable {
    case atTime, oneHourBefore, oneDayBefore
    var label: String { … }               // "At time", "1 hour before", "1 day before"
    var relativeOffset: TimeInterval { … } // 0, -3600, -86400
}
```

Add `reminder: ReminderOffset? = nil` parameter to `addHouseholdTask`, `addAppointment`, `addPetEvent`. When non-nil, attach `EKAlarm(relativeOffset: reminder.relativeOffset)` to the `EKEvent`. Default `nil` keeps existing call sites (`AppointmentsTabView`, and current `TasksView`/`EventsTabView` calendar actions) compiling unchanged.

### `HouseholdTask`

Add `func snoozed(byDays days: Int) -> HouseholdTask` (adds `days` to `nextDueDate` via `Calendar.current`). Refactor existing `snoozedByOneDay()` to `snoozed(byDays: 1)` (keep or inline the old name — verify no other callers before removing; codegraph shows only `TasksView.snooze`).

### Out-of-stock feedback (the one non-fire-and-forget case)

`completeTask` returns `CompletionResult`; `TasksView` currently shows an out-of-stock alert. A reusable menu cannot present an alert. Solution:

```swift
struct TaskContextMenu: View {
    let task: HouseholdTask
    var onCompleted: ((SupabaseStore.CompletionResult) -> Void)? = nil
    …
}
```

`TasksView` passes a closure that raises its existing alert. Other screens omit it → silent complete. This is the only optional plumbing.

## Screens Edited (swipe → menu)

- `TasksView.swift` — remove leading/trailing swipeActions; add `.contextMenu { TaskContextMenu(task:) { … } }` for tasks, `EventContextMenu` for events. Keep out-of-stock alert wired via `onCompleted`.
- `StockView.swift` — remove swipeActions; add `StockContextMenu(product:)`.
- `AppointmentsTabView.swift` — remove swipeActions (upcoming + past); add `AppointmentContextMenu(appointment:pet:)`.
- `EventsTabView.swift` — remove swipeActions; add `EventContextMenu`.
- `PetsView.swift` — inline delete `.contextMenu`.
- `VetTabView.swift` — inline delete `.contextMenu`.
- `ClinicalHistoryTabView.swift` — inline delete `.contextMenu`.
- `MealSlotRow.swift` — replace leading Cook swipe with `.contextMenu { Button("Cocinado") { onCook() } }`.
- `SearchView.swift` — refactor: replace private `stockMenu`/`taskMenu` helpers with the new shared `StockContextMenu`/`TaskContextMenu`. Keep `mealMenu`/`petMenu` as private inline helpers (no shared type for meal/pet).
- `FilesTabView.swift` — already `.contextMenu`; no change needed (verify consistency).

## Testing

- Unit tests (Swift Testing, `HomeTests/`):
  - `HouseholdTask.snoozed(byDays:)` — correct date offset for several N.
  - `CalendarService.ReminderOffset.relativeOffset` — correct seconds per case.
- Menu `View`s are not unit-tested.
- Build must succeed (`Cmd+B`, zero errors, Swift 6 strict concurrency clean) and all tests pass (`Cmd+U`) before commit.

## Out of Scope (YAGNI)

- Custom date picker for snooze ("Pick a date…").
- Custom amount picker for consume ("Consume N…").
- Delete confirmation dialogs.
- Context menu preview customization.
- Changes to drag-to-reorder (`DashboardEditView`).

## Accessibility

Context menu items carry their own labels via `Label`. Icon-only trigger rows unaffected (menu is long-press on the whole row). No new icon-only buttons introduced.
