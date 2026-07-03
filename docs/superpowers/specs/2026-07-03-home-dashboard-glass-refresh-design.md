# Home Dashboard Glass Refresh — Design

**Date:** 2026-07-03
**Scope:** Home tab (`DashboardView`) only. No data-layer, sync, or navigation changes.
**Direction:** Clean iOS 26 material glass — minimal, native, restrained motion.

## Goal

The Home dashboard currently renders flat grey cards (`.background.secondary`,
corner radius 16) with plain `HStack` rows. It reads as a generic system list.
Refresh it into a polished, native iOS 26 dashboard using material glass, subtle
per-section color, a greeting header, and tasteful spring motion — without
changing behavior, data flow, or the offline-first architecture.

## Non-goals

- No changes to shared rows used outside Home (`StockProductRow`, `SearchMealRow`,
  `SearchTaskRow`) beyond how they already render inside cards.
- No changes to `DashboardData`, `SupabaseStore`, sync, or the outbox.
- No changes to the Edit / Add-task flows or `DashboardConfigStore` persistence.
- No entrance-stagger choreography (deferred; user chose plain subtle motion).

## Files touched

| File | Change |
|---|---|
| `Home/Home/DashboardCard.swift` | Add `var tint: Color` per case. |
| `Home/Home/DashboardCardView.swift` | Adopt `PressableGlassCard`, tinted icon chip, count pill, numeric-text count, row insert/remove animation. |
| `Home/Home/DashboardView.swift` | Add greeting header at top of scroll; nav title inline; animate card/data changes. |
| `Home/Home/PressableGlassCard.swift` | **New.** Reusable glass card container + press-spring modifier. |
| `Home/Home/DashboardHeaderView.swift` | **New.** Greeting + date + summary strip. |

## Component design

### 1. `PressableGlassCard` (new, reusable)

A container that wraps arbitrary card content and owns the entire card look, so
the visual language lives in one place.

- Fill: `.regularMaterial` in `.rect(cornerRadius: 20)`.
- Edge: hairline `.stroke(.white.opacity(0.08), lineWidth: 0.5)` on the same shape.
- Shadow: `color: .black.opacity(0.06), radius: 8, y: 4`.
- Press feedback: `@State private var pressed` driving
  `.scaleEffect(pressed ? 0.97 : 1)` with `.spring(response: 0.3, dampingFraction: 0.7)`.
  Driven by a `DragGesture(minimumDistance: 0)` attached with `.simultaneousGesture`
  so inner row `onTapGesture` handlers keep working (nested taps must not break).
- Tap action passed in as a closure (used for deep-link navigation).

Interface:

```
struct PressableGlassCard<Content: View>: View {
    let onTap: () -> Void
    @ViewBuilder var content: () -> Content
}
```

Depends on: nothing app-specific. Pure presentation.

### 2. `DashboardCard.tint`

Add a computed accent color per case — the only place color enters the design:

- `.upcomingTasks` → `.blue`
- `.shoppingList` → `.green`
- `.weekMeals` → `.orange`
- `.appointments` → `.pink`

`DashboardCard` is `nonisolated`; `Color` is `Sendable`, so this stays clean.

### 3. `DashboardCardView`

- Wrap body in `PressableGlassCard { navigate() }`, dropping the manual
  `.background` / `.contentShape` / `.onTapGesture`.
- Header icon becomes a **tinted chip**: `Image(systemName:)` at ~15pt,
  `.foregroundStyle(card.tint)`, frame 32×32, background `card.tint.opacity(0.15)`
  in `.rect(cornerRadius: 9)`. Marked `.accessibilityHidden(true)` (title conveys it).
- Header count pill: number in `.caption.weight(.semibold)`, horizontal padding,
  `Capsule().fill(.quaternary)` background. Apply `.contentTransition(.numericText())`.
- Content rows (tasks/appointments/shopping/meals): wrap the `ForEach` result so
  inserts/removals animate — `.animation(.spring, value:)` keyed on the item ids,
  with `.transition(.opacity.combined(with: .move(edge: .top)))` on rows.

### 4. `DashboardHeaderView` (new)

- Greeting from current hour: <12 "Good morning", <18 "Good afternoon", else
  "Good evening". Uses `@MainActor` default isolation; reads `Date.now`.
- Date line: `.now.formatted(.dateTime.weekday(.wide).day().month(.wide))`.
- Summary strip: compact counts, e.g. `3 tasks today · 2 to buy`, built from
  the same `DashboardData` helpers the cards already use (no new queries).
  `.contentTransition(.numericText())` on the numbers.
- Typography: greeting `.title.bold()`, date + summary `.subheadline`
  `.foregroundStyle(.secondary)`.

### 5. `DashboardView`

- Set `.navigationBarTitleDisplayMode(.inline)` and drop the large "Home" title
  in favor of the greeting header as the first element of the `LazyVStack`
  (header is a normal scrolling row, not pinned).
- Keep Edit / Add-task toolbar buttons unchanged.
- Add `.animation(.spring, value: config.cards)` so reorder/enable changes glide.

## Style-guide compliance (project CLAUDE.md)

- `.rect(cornerRadius:)` everywhere, never `RoundedRectangle` in `clipShape`.
- `.tint` semantics preserved for app-tint foregrounds; per-card colors are
  explicit accent colors, not `Color.accentColor`.
- Icon-only chips are decorative → `.accessibilityHidden(true)`; the Add/Edit
  toolbar buttons already carry labels.
- Swift 6 strict concurrency: all new types default `@MainActor`; `DashboardCard`
  stays `nonisolated` and `Color` is `Sendable`.
- One primary type per file; two new files for the two new types.

## Testing

Primarily visual. Verify via Xcode preview + simulator:

- Cards render as floating glass with correct per-type chip colors.
- Press-scale springs on tap; inner task rows still open the task sheet;
  deep-link cards still navigate.
- Greeting matches time of day; date + summary correct; numbers animate on change.
- Empty states (no cards, empty card content) unchanged.
- Light + dark mode both legible (material + hairline stroke).
- No new concurrency warnings; `Cmd+B` clean, `Cmd+U` green.

## Risks

- Material glass over the default grouped background can look flat; the hairline
  stroke + shadow mitigate. Validate in both color schemes early.
- Simultaneous press gesture vs. inner row taps — verify no swallowed taps.
