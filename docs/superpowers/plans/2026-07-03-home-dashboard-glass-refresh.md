# Home Dashboard Glass Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Home dashboard into an iOS 26 material-glass look — floating glass cards with tinted icon chips, a greeting header, and subtle spring motion — with zero data-layer changes.

**Architecture:** All changes are presentation-only, inside `Home/Home/`. A new reusable `PressableGlassCard` container owns the card look; a new `DashboardHeaderView` renders greeting/date/summary; `DashboardCard` gains a `tint` color; `DashboardCardView` and `DashboardView` adopt them. Spec: `docs/superpowers/specs/2026-07-03-home-dashboard-glass-refresh-design.md`.

**Tech Stack:** SwiftUI (iOS 26 SDK, min APIs are iOS 17-safe), Swift Testing (`@Suite`/`#expect`), Xcode-only build/test.

## Global Constraints

- Swift 6 strict concurrency; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Zero new warnings.
- Build/test ONLY through Xcode: build `Cmd+B`, tests `Cmd+U`. There is no CLI build. When a step says "Run tests", ask the user to run `Cmd+U` (or the single suite from the diamond gutter) and report the result.
- Test target imports the app module as `@testable import Casita` (PRODUCT_NAME is Casita; targets are named `Home`/`HomeTests`).
- New source files MUST be registered in `Home.xcodeproj` via `bundle exec ruby scripts/pbxadd.rb <group/path> <Filename.swift> <Target>` (fixed in Task 1) — Xcode project does NOT use synchronized folders.
- Style: `.rect(cornerRadius:)` shapes in `background(_:in:)`/`clipShape`; `.tint` semantics reserved for app tint; icon-only decorative images get `.accessibilityHidden(true)`; one primary type per file; no comments unless WHY is non-obvious.
- Commits: conventional, English (`feat:`, `fix:`, `chore:`).
- Do NOT touch: `DashboardData`, `SupabaseStore`, sync/outbox, `HomeItemRow`, `StockProductRow`, `SearchMealRow`, `DashboardEditView`, `DashboardConfigStore`.

---

### Task 1: Fix `scripts/pbxadd.rb` file-existence check

The script aborts on its documented usage: `File.exist?(filename)` receives a bare filename (e.g. `Supermarket.swift`) which never exists at the repo root, while `new_reference` needs the bare filename to build a correct group-relative path. Passing a repo-relative path instead silently registers a broken duplicate (verified: it added `Home/Stock/Home/Stock/Supermarket.swift`).

**Files:**
- Modify: `scripts/pbxadd.rb:9`

**Interfaces:**
- Produces: working invocation `bundle exec ruby scripts/pbxadd.rb <group/path> <Filename.swift> <TargetName>` run from the repo root — used by Tasks 2, 3, 4.

- [ ] **Step 1: Fix the existence check**

Replace line 9 of `scripts/pbxadd.rb`:

```ruby
abort "file not found: #{filename}" unless File.exist?(filename)
```

with:

```ruby
abort "file not found: #{File.join(group_path, filename)}" unless File.exist?(File.join(group_path, filename))
```

- [ ] **Step 2: Verify with an already-registered file (idempotent, no mutation)**

Run: `bundle exec ruby scripts/pbxadd.rb Home/Stock Supermarket.swift Home`
Expected output: `already registered: Supermarket.swift`

Run: `git status --porcelain Home.xcodeproj`
Expected: empty (no pbxproj mutation).

- [ ] **Step 3: Commit**

```bash
git add scripts/pbxadd.rb
git commit -m "fix: pbxadd existence check resolves file relative to group path"
```

---

### Task 2: `DashboardCard.tint`

**Files:**
- Modify: `Home/Home/DashboardCard.swift` (add computed property to the enum, after `systemImage`)
- Test: `HomeTests/DashboardCardTintTests.swift` (create)

**Interfaces:**
- Consumes: nothing new.
- Produces: `var tint: Color` on `DashboardCard` — `.upcomingTasks → .blue`, `.shoppingList → .green`, `.weekMeals → .orange`, `.appointments → .pink`. Used by Task 5.

- [ ] **Step 1: Write the failing test**

Create `HomeTests/DashboardCardTintTests.swift`:

```swift
import Testing
import SwiftUI
@testable import Casita

@Suite("DashboardCard tint") struct DashboardCardTintTests {

    @Test("each card carries its designed accent color")
    func tints() {
        #expect(DashboardCard.upcomingTasks.tint == .blue)
        #expect(DashboardCard.shoppingList.tint == .green)
        #expect(DashboardCard.weekMeals.tint == .orange)
        #expect(DashboardCard.appointments.tint == .pink)
    }
}
```

- [ ] **Step 2: Register the test file with the test target**

Run: `bundle exec ruby scripts/pbxadd.rb HomeTests DashboardCardTintTests.swift HomeTests`
Expected: `added HomeTests/DashboardCardTintTests.swift to HomeTests`

- [ ] **Step 3: Verify it fails**

Ask the user to run tests (`Cmd+U`).
Expected: build FAILS with `value of type 'DashboardCard' has no member 'tint'` (compile failure is the red state).

- [ ] **Step 4: Implement `tint`**

In `Home/Home/DashboardCard.swift`, after the `systemImage` property (line 28), add:

```swift
    var tint: Color {
        switch self {
        case .upcomingTasks: .blue
        case .shoppingList:  .green
        case .weekMeals:     .orange
        case .appointments:  .pink
        }
    }
```

(`DashboardCard` is `nonisolated`; `Color` is `Sendable` — no isolation changes needed. The file already imports SwiftUI.)

- [ ] **Step 5: Verify it passes**

Ask the user to run tests (`Cmd+U`).
Expected: all tests PASS, including `DashboardCard tint`.

- [ ] **Step 6: Commit**

```bash
git add Home/Home/DashboardCard.swift HomeTests/DashboardCardTintTests.swift Home.xcodeproj/project.pbxproj
git commit -m "feat: add per-card accent tint to DashboardCard"
```

---

### Task 3: `DashboardHeaderView` — greeting, date, summary

**Files:**
- Create: `Home/Home/DashboardHeaderView.swift`
- Test: `HomeTests/DashboardHeaderTests.swift` (create)

**Interfaces:**
- Consumes: nothing app-specific.
- Produces (used by Task 6):
  - `struct DashboardHeaderView: View` with stored properties `let tasksDueToday: Int`, `let itemsToBuy: Int`.
  - `static func greeting(hour: Int) -> String` — `0..<12` → `"Good morning"`, `12..<18` → `"Good afternoon"`, else `"Good evening"`.
  - `static func summary(tasksDueToday: Int, itemsToBuy: Int) -> String?` — `nil` when both are 0; segments `"N task(s) today"` (singular at 1) and `"N to buy"`, joined with `" · "`, zero-count segments omitted.

- [ ] **Step 1: Write the failing tests**

Create `HomeTests/DashboardHeaderTests.swift`:

```swift
import Testing
@testable import Casita

@Suite("DashboardHeaderView logic") @MainActor struct DashboardHeaderTests {

    @Test("greeting follows the hour of day")
    func greeting() {
        #expect(DashboardHeaderView.greeting(hour: 0) == "Good morning")
        #expect(DashboardHeaderView.greeting(hour: 11) == "Good morning")
        #expect(DashboardHeaderView.greeting(hour: 12) == "Good afternoon")
        #expect(DashboardHeaderView.greeting(hour: 17) == "Good afternoon")
        #expect(DashboardHeaderView.greeting(hour: 18) == "Good evening")
        #expect(DashboardHeaderView.greeting(hour: 23) == "Good evening")
    }

    @Test("summary joins non-zero segments with a middle dot")
    func summaryBoth() {
        #expect(DashboardHeaderView.summary(tasksDueToday: 3, itemsToBuy: 2) == "3 tasks today · 2 to buy")
    }

    @Test("summary singularizes one task and omits zero segments")
    func summaryEdges() {
        #expect(DashboardHeaderView.summary(tasksDueToday: 1, itemsToBuy: 0) == "1 task today")
        #expect(DashboardHeaderView.summary(tasksDueToday: 0, itemsToBuy: 4) == "4 to buy")
        #expect(DashboardHeaderView.summary(tasksDueToday: 0, itemsToBuy: 0) == nil)
    }
}
```

- [ ] **Step 2: Register the test file**

Run: `bundle exec ruby scripts/pbxadd.rb HomeTests DashboardHeaderTests.swift HomeTests`
Expected: `added HomeTests/DashboardHeaderTests.swift to HomeTests`

- [ ] **Step 3: Verify it fails**

Ask the user to run tests (`Cmd+U`).
Expected: build FAILS with `cannot find 'DashboardHeaderView' in scope`.

- [ ] **Step 4: Implement the view**

Create `Home/Home/DashboardHeaderView.swift`:

```swift
import SwiftUI

struct DashboardHeaderView: View {
    let tasksDueToday: Int
    let itemsToBuy: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.greeting(hour: Calendar.current.component(.hour, from: .now)))
                .font(.title.bold())
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let summary = Self.summary(tasksDueToday: tasksDueToday, itemsToBuy: itemsToBuy) {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func greeting(hour: Int) -> String {
        switch hour {
        case ..<12: "Good morning"
        case ..<18: "Good afternoon"
        default:    "Good evening"
        }
    }

    static func summary(tasksDueToday: Int, itemsToBuy: Int) -> String? {
        var parts: [String] = []
        if tasksDueToday > 0 {
            parts.append("\(tasksDueToday) task\(tasksDueToday == 1 ? "" : "s") today")
        }
        if itemsToBuy > 0 {
            parts.append("\(itemsToBuy) to buy")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    DashboardHeaderView(tasksDueToday: 3, itemsToBuy: 2)
        .padding()
}
```

- [ ] **Step 5: Register the source file with the app target**

Run: `bundle exec ruby scripts/pbxadd.rb Home/Home DashboardHeaderView.swift Home`
Expected: `added Home/Home/DashboardHeaderView.swift to Home`

- [ ] **Step 6: Verify it passes**

Ask the user to run tests (`Cmd+U`).
Expected: all tests PASS, including the three `DashboardHeaderView logic` tests.

- [ ] **Step 7: Commit**

```bash
git add Home/Home/DashboardHeaderView.swift HomeTests/DashboardHeaderTests.swift Home.xcodeproj/project.pbxproj
git commit -m "feat: add dashboard greeting header with date and summary"
```

---

### Task 4: `PressableGlassCard` container

Pure presentation — no unit-testable logic; verified by build + preview in Task 7.

**Files:**
- Create: `Home/Home/PressableGlassCard.swift`

**Interfaces:**
- Consumes: nothing app-specific.
- Produces (used by Task 5): `struct PressableGlassCard<Content: View>: View` with initializer `PressableGlassCard(onTap: () -> Void, @ViewBuilder content: () -> Content)`. Renders its content in a `VStack(alignment: .leading, spacing: 12)` with glass styling and press-scale.

- [ ] **Step 1: Create the view**

Create `Home/Home/PressableGlassCard.swift`:

```swift
import SwiftUI

struct PressableGlassCard<Content: View>: View {
    let onTap: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(18)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .contentShape(.rect(cornerRadius: 20))
            .onTapGesture(perform: onTap)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

#Preview {
    PressableGlassCard(onTap: {}) {
        Text("Header").font(.headline)
        Text("Row content")
    }
    .padding()
}
```

(WHY `.simultaneousGesture` + zero-distance drag: press feedback must not swallow the card's `.onTapGesture` or inner row `onTapGesture` handlers — inner taps keep precedence exactly as today.)

- [ ] **Step 2: Register the file**

Run: `bundle exec ruby scripts/pbxadd.rb Home/Home PressableGlassCard.swift Home`
Expected: `added Home/Home/PressableGlassCard.swift to Home`

- [ ] **Step 3: Verify it builds**

Ask the user to build (`Cmd+B`) and open the `PressableGlassCard` preview.
Expected: zero errors/warnings; preview shows a floating glass card; tapping it scales down briefly.

- [ ] **Step 4: Commit**

```bash
git add Home/Home/PressableGlassCard.swift Home.xcodeproj/project.pbxproj
git commit -m "feat: add reusable pressable glass card container"
```

---

### Task 5: Adopt glass styling in `DashboardCardView`

**Files:**
- Modify: `Home/Home/DashboardCardView.swift`

**Interfaces:**
- Consumes: `PressableGlassCard` (Task 4), `DashboardCard.tint` (Task 2).
- Produces: no interface changes — same `DashboardCardView(card:onSelectTask:)` signature.

- [ ] **Step 1: Replace `body` and `header`**

In `Home/Home/DashboardCardView.swift`, replace the current `body` (lines 14–23) and `header` (lines 25–45) with:

```swift
    var body: some View {
        PressableGlassCard(onTap: navigate) {
            header
            content
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: card.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(card.tint)
                .frame(width: 32, height: 32)
                .background(card.tint.opacity(0.15), in: .rect(cornerRadius: 9))
                .accessibilityHidden(true)
            Text(card.title).font(.headline)
            Spacer()
            if let count = headerCount {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: .capsule)
                    .contentTransition(.numericText())
            }
            if card.deepLinkHost != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
```

The old `.padding(18)` / `.background(...)` / `.contentShape(...)` / `.onTapGesture { navigate() }` chain on the outer `VStack` is now owned by `PressableGlassCard` — delete it entirely. `navigate()` stays unchanged (its `guard let host` already no-ops for `.upcomingTasks`).

- [ ] **Step 2: Animate row insert/remove in the tasks branch**

In `content`, replace the `.upcomingTasks` case body's non-empty branch with:

```swift
            if items.isEmpty {
                emptyState("Nothing scheduled")
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        HomeItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if case .task(let t) = item { onSelectTask(t) }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.spring(duration: 0.35), value: items.map(\.id))
            }
```

(Only the tasks branch animates rows — it is the one that mutates in place via mark-done/snooze. Other branches change only via full-store refresh; leave them as they are.)

- [ ] **Step 3: Verify it builds**

Ask the user to build (`Cmd+B`).
Expected: zero errors, zero new warnings.

- [ ] **Step 4: Commit**

```bash
git add Home/Home/DashboardCardView.swift
git commit -m "feat: restyle dashboard cards with glass container and tinted chips"
```

---

### Task 6: Integrate header + animations in `DashboardView`

**Files:**
- Modify: `Home/Home/DashboardView.swift`

**Interfaces:**
- Consumes: `DashboardHeaderView` (Task 3). Reads `store.householdTasks` (`HouseholdTask.nextDueDate: Date`) and `DashboardData.shoppingList(stock:limit:) -> (items: [StockProduct], total: Int)`.
- Produces: no interface changes.

- [ ] **Step 1: Restructure `body`**

Replace the `ScrollView { ... }` contents of `Home/Home/DashboardView.swift` (lines 15–33) with:

```swift
            ScrollView {
                LazyVStack(spacing: 14) {
                    DashboardHeaderView(
                        tasksDueToday: tasksDueToday,
                        itemsToBuy: DashboardData.shoppingList(
                            stock: store.stockProducts,
                            limit: DashboardData.shoppingLimit).total
                    )
                    .padding(.bottom, 6)

                    if config.cards.isEmpty {
                        ContentUnavailableView(
                            "No cards",
                            systemImage: "square.grid.2x2",
                            description: Text("Tap Edit to add dashboard cards.")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(config.cards) { card in
                            DashboardCardView(card: card) { task in
                                editingTask = task
                            }
                        }
                    }
                }
                .padding(16)
                .animation(.spring(duration: 0.35), value: config.cards)
            }
```

And after the `.navigationTitle("Home")` line add:

```swift
            .navigationBarTitleDisplayMode(.inline)
```

- [ ] **Step 2: Add the `tasksDueToday` helper**

Add to `DashboardView` (below `body`):

```swift
    private var tasksDueToday: Int {
        let today = Calendar.current.startOfDay(for: .now)
        return store.householdTasks
            .filter { Calendar.current.startOfDay(for: $0.nextDueDate) <= today }
            .count
    }
```

- [ ] **Step 3: Verify build + tests**

Ask the user to build (`Cmd+B`) and run tests (`Cmd+U`).
Expected: build clean, all tests PASS (no behavior under test changed).

- [ ] **Step 4: Commit**

```bash
git add Home/Home/DashboardView.swift
git commit -m "feat: add greeting header and spring animations to dashboard"
```

---

### Task 7: Visual verification pass

No code — acceptance check against the spec. Fix-forward anything found, as amendments to the owning task's file with a `fix:` commit.

- [ ] **Step 1: Run the app (`Cmd+R`) and verify in the simulator**

Checklist (from spec "Testing"):
- Cards float: glass material, rounded 20, hairline edge, soft shadow.
- Icon chips tinted: tasks blue, shopping green, meals orange, appointments pink.
- Press a card → springs to 0.97 and back; releases cleanly after scroll-drag.
- Tap a task row → task sheet opens (inner tap not swallowed).
- Tap shopping/meals/appointments card body → deep-link navigation still works.
- Header greeting matches current time of day; date correct; summary counts match card contents.
- Mark a task done → row animates out; count pill and summary animate numerically.
- Empty states: disable all cards (Edit) → header + `ContentUnavailableView`; empty card content unchanged.
- Toggle dark mode (simulator `Cmd+Shift+A`) → material + stroke legible in both schemes.

- [ ] **Step 2: Confirm zero concurrency warnings**

Xcode issue navigator after `Cmd+B`: no new warnings of any kind.

- [ ] **Step 3: Final commit if amendments were made**

```bash
git status
```

If clean: done. If amendments: commit each with `fix:` scoped to the file touched.
