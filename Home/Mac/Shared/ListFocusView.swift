#if os(macOS)
import AppKit
import SwiftUI

// Clicking (or AX-selecting, as in UI tests) a List row changes the SwiftUI
// `selection` binding but never promotes the List's backing NSOutlineView to
// `NSWindow.firstResponder` on this SDK — confirmed by instrumenting
// `window.firstResponder` directly: after a row click it stays the window itself,
// so `.onDeleteCommand`, `.onKeyPress`, and `contextMenu(forSelectionType:)`'s own
// Return handling (which only reaches `primaryAction` once the outline view is
// first responder) never fire. Promoting the outline view to first responder
// fixes all three natively, with no event interception — but only the ONE time
// the selection actually changes (`shouldApplyFocus`/`Coordinator.lastAppliedSelection`):
// `updateNSView` otherwise runs on every unrelated body re-render (a sync pull, a
// calendar feed load, an inspector field edit), and re-grabbing focus on each of
// those would yank it away from non-text inspector controls (DatePicker, Stepper,
// Picker, the Save button) and the sidebar whenever nothing else currently holds
// it (`applyFocus`'s guard: only promote when the current first responder is the
// window itself, nil, or already the outline view).
//
// A SwiftUI `Table` has the identical problem but is backed by a plain
// `NSTableView`, not an `NSOutlineView` — so the search below matches on
// `NSTableView` (the superclass both share) rather than `NSOutlineView`
// specifically, letting `List`- and `Table`-based Mac features (Stock's
// `MacStockView`) reuse the exact same focus dance.
//
// `nearestOutlineView` is scoped to the outline/table view owned by the pane
// this view lives in: it climbs `nsView`'s own superview chain (this view sits
// as a `.background` of the feature `List`/`Table`, inside the detail pane)
// rather than searching from `window.contentView`, which would also contain
// the sidebar's own `NSOutlineView` and could match that one instead (see
// `ListFocusViewTests.scopesToTheOwningPane`).
//
// Generic over the List's selection type so every Mac feature list (Today's
// `AgendaItem.ID`, Tasks' `HouseholdTask.ID`, …) can reuse this instead of
// reimplementing the same focus dance.
struct ListFocusView<Selection: Hashable>: NSViewRepresentable {
    let selection: Selection?

    final class Coordinator {
        var lastAppliedSelection: Selection?

        /// An attempt that couldn't find its window or list (still mid-layout) is
        /// forgotten so the next update retries it; one that found them but declined
        /// because another control holds focus stays recorded — that refusal is correct.
        func focusAttempt(for selection: Selection, resolved: Bool) {
            guard !resolved, lastAppliedSelection == selection else { return }
            lastAppliedSelection = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        guard Self.shouldApplyFocus(selection: selection, coordinator: coordinator),
              let selection else { return }
        coordinator.lastAppliedSelection = selection
        // The outline view isn't always findable yet in this same SwiftUI commit
        // (it can still be mid-layout right after a selection-driven re-render),
        // so promotion is deferred one main-actor turn rather than attempted here.
        // This hop happens once per selection change, never once per render.
        Task { @MainActor in
            coordinator.focusAttempt(for: selection, resolved: Self.applyFocus(from: nsView))
        }
    }

    static func shouldApplyFocus(selection: Selection?, coordinator: Coordinator) -> Bool {
        guard let selection else {
            coordinator.lastAppliedSelection = nil
            return false
        }
        return coordinator.lastAppliedSelection != selection
    }

    /// Returns false only when there is no window or list to focus yet.
    static func applyFocus(from view: NSView) -> Bool {
        guard let window = view.window, let outlineView = nearestOutlineView(ascendingFrom: view) else { return false }
        let responder = window.firstResponder
        guard responder == nil || responder === window || responder === outlineView else { return true }
        window.makeFirstResponder(outlineView)
        return true
    }

    static func nearestOutlineView(ascendingFrom view: NSView) -> NSTableView? {
        var ancestor = view.superview
        while let current = ancestor {
            if let found = outlineView(in: current) { return found }
            ancestor = current.superview
        }
        return nil
    }

    private static func outlineView(in view: NSView) -> NSTableView? {
        if let tableView = view as? NSTableView { return tableView }
        for subview in view.subviews {
            if let found = outlineView(in: subview) { return found }
        }
        return nil
    }
}
#endif
