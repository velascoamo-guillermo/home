# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Building and Testing

Build and test only through Xcode — there is no CLI build script.

- **Build**: `Cmd+B` — must succeed with zero errors before committing.
- **Test**: `Cmd+U` — all tests must pass.
- **Run**: `Cmd+R` — simulator or device.

## Local Configuration

`Config.xcconfig` (git-ignored) must exist at the repo root with:

```
SUPABASE_URL = https://...
SUPABASE_ANON_KEY = eyJ...
```

These are injected into `Info.plist` at build time and read by `SupabaseConfig`. The app will `fatalError` at launch if either key is missing.

Apply Supabase schema migrations with:

```
supabase db push
```

Migrations live in `supabase/migrations/`.

---

## Swift 6 Strict Concurrency

**This project targets Swift 6 with full strict concurrency. Never regress to Swift 5.**

| Setting | Value |
|---|---|
| `SWIFT_VERSION` | `6.0` |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` |

### Rules

- All new code must compile clean — zero concurrency errors, zero data-race warnings.
- `@MainActor` is the default isolation for every type. Only mark `nonisolated` or `actor` when there is a clear reason.
- Never use `@unchecked Sendable`, `nonisolated(unsafe)`, or `@preconcurrency` without a documented safety invariant in the same file.
- Prefer `async/await` over `DispatchQueue`, `OperationQueue`, or `Timer` for new code.
- `Task { }` inherits caller isolation (`@MainActor` by default). Use `Task { @concurrent in ... }` + `await MainActor.run { }` when the work does not need the main actor.
- No `Task.detached` without a written reason.

### Migration debt — forbidden in new code

- `DispatchQueue.main.async` → `await MainActor.run { }` or `@MainActor func`
- `DispatchQueue.global().async` → `Task { @concurrent in ... }`
- Bare `Thread` APIs

---

## Architecture

### Data layer — `SupabaseStore`

`SupabaseStore` (`@Observable`, `final class`) is the single source of truth for all app data. It owns a `SupabaseClient` and exposes typed arrays for every entity:

```
pets, veterinarians, appointments, clinicalEntries,
events, files, householdTasks, customSections
```

All mutations follow the same two-step pattern: call Supabase, then update the in-memory array. There is no caching layer or local persistence beyond this in-memory state.

Binary files are stored in the `pet-files` Supabase Storage bucket. `storagePath` is `<petId>/<fileId>.<ext>`.

`SupabaseStore` is created once in `ContentView` and injected via `.environment(store)` so every view in the hierarchy accesses it with `@Environment(SupabaseStore.self)`.

### App entry point

```
HomeApp → ContentView (creates SupabaseStore, calls loadAll(), injects via .environment)
        → loading/error gate
        → MainTabView (4 tabs: Home, Pets, Shop, Settings)
```

### Home tab — unified timeline

`HomeView` displays `store.homeTimeline`, a computed property on `SupabaseStore` that merges upcoming `Appointment` entries and all `HouseholdTask` entries into `[HomeItem]`, sorted by due date.

`HomeItem` is an enum (`case appointment(Appointment, Pet)`, `case task(HouseholdTask)`) — add new timeline entry types here.

Task actions (mark done, snooze, delete, add to calendar) are handled in `HomeView` helper methods.

### Pets tab — per-pet detail

`PetsView` → `PetDetailView` (tabbed: Vet, Appointments, Clinical History, Events, Files).

Each tab reads filtered data from `SupabaseStore` via `appointments(for:)`, `clinicalEntries(for:)`, etc.

`ExtractionService` calls the Claude API to parse vet documents into structured `ClinicalEntry` data.

### Household tasks — sections

`HouseholdTask` has an optional `sectionId`. Sections are either predefined (`TaskSection.Predefined` enum, icon-keyed) or custom (`TaskSection`, stored in Supabase `task_sections` table).

`TaskSectionPicker` → `AddCustomSectionSheet` → `SFSymbolPicker` is the section-assignment flow launched from `HouseholdTaskSheet`.

---

## Code Style

- No third-party dependencies except the Supabase Swift SDK.
- API keys in `Config.xcconfig` and Keychain only — never hardcode.
- Each Swift file has one primary type.
- No comments unless the WHY is non-obvious.
- No `@discardableResult` on new functions except where the caller pattern clearly warrants it.
- Accessibility: all icon-only buttons need `.accessibilityLabel`. Decorative images need `.accessibilityHidden(true)`.
- Use `.tint` (not `.accent` or `Color.accentColor`) for `foregroundStyle` referencing the app tint.
- Use `.clipShape(.rect(cornerRadius:))` not `clipShape(RoundedRectangle(cornerRadius:))`.
