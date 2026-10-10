#if os(macOS)
import Testing
import AppKit
@testable import Casita

/// `NSOutlineView.acceptsFirstResponder` (and therefore real `NSWindow.makeFirstResponder`
/// promotion) only succeeds once a window is genuinely key/on screen, which a plain unit
/// test host doesn't guarantee. `RecordingWindow` simulates the first-responder slot itself
/// so these tests exercise `ListFocusView<String>`'s own guard logic deterministically,
/// independent of AppKit's real focus machinery.
private final class RecordingWindow: NSWindow {
    private var simulatedFirstResponder: NSResponder?
    override var firstResponder: NSResponder? { simulatedFirstResponder }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backing, defer: flag)
        simulatedFirstResponder = self
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        simulatedFirstResponder = responder ?? self
        return true
    }
}

@Suite("ListFocusView") @MainActor struct ListFocusViewTests {
    /// sidebar outline (first in the tree) + a separate detail pane outline, mirroring
    /// MacShellView's NavigationSplitView: sidebar and detail are disjoint branches.
    private struct Fixture {
        let window: NSWindow
        let background: NSView
        let sidebarOutline: NSOutlineView
        let detailOutline: NSOutlineView
    }

    private func makeFixture() -> Fixture {
        let window = RecordingWindow(contentRect: .init(x: 0, y: 0, width: 400, height: 300),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
        let root = NSView()
        window.contentView = root

        let sidebarPane = NSView()
        let sidebarScroll = NSScrollView()
        let sidebarOutline = NSOutlineView()
        sidebarScroll.documentView = sidebarOutline
        sidebarPane.addSubview(sidebarScroll)
        root.addSubview(sidebarPane)

        let detailPane = NSView()
        let container = NSView()
        let background = NSView()
        let detailScroll = NSScrollView()
        let detailOutline = NSOutlineView()
        detailScroll.documentView = detailOutline
        container.addSubview(background)
        container.addSubview(detailScroll)
        detailPane.addSubview(container)
        root.addSubview(detailPane)

        return Fixture(window: window, background: background, sidebarOutline: sidebarOutline, detailOutline: detailOutline)
    }

    @Test("nearestOutlineView finds the detail pane's own outline, never the sidebar's")
    func scopesToTheOwningPane() {
        let fixture = makeFixture()
        let found = ListFocusView<String>.nearestOutlineView(ascendingFrom: fixture.background)
        #expect(found === fixture.detailOutline)
        #expect(found !== fixture.sidebarOutline)
    }

    @Test("shouldApplyFocus only fires once per distinct selection")
    func shouldApplyFocusTracksLastSelection() {
        let coordinator = ListFocusView<String>.Coordinator()
        #expect(ListFocusView<String>.shouldApplyFocus(selection: nil, coordinator: coordinator) == false)
        #expect(ListFocusView<String>.shouldApplyFocus(selection: "a", coordinator: coordinator) == true)
        coordinator.lastAppliedSelection = "a"
        #expect(ListFocusView<String>.shouldApplyFocus(selection: "a", coordinator: coordinator) == false)
        #expect(ListFocusView<String>.shouldApplyFocus(selection: "b", coordinator: coordinator) == true)
    }

    @Test("clearing the selection forgets it, so reselecting the same row grabs focus again")
    func deselectThenReselectSameRow() {
        let coordinator = ListFocusView<String>.Coordinator()
        coordinator.lastAppliedSelection = "a"
        #expect(ListFocusView<String>.shouldApplyFocus(selection: nil, coordinator: coordinator) == false)
        #expect(ListFocusView<String>.shouldApplyFocus(selection: "a", coordinator: coordinator) == true)
    }

    @Test("a focus attempt that found no window or list is retried on the next update")
    func unresolvedAttemptIsRetried() {
        let coordinator = ListFocusView<String>.Coordinator()
        coordinator.lastAppliedSelection = "a"
        coordinator.focusAttempt(for: "a", resolved: false)
        #expect(ListFocusView<String>.shouldApplyFocus(selection: "a", coordinator: coordinator) == true)
    }

    @Test("a stale unresolved attempt does not reset a newer selection")
    func staleUnresolvedAttemptIgnored() {
        let coordinator = ListFocusView<String>.Coordinator()
        coordinator.lastAppliedSelection = "b"
        coordinator.focusAttempt(for: "a", resolved: false)
        #expect(ListFocusView<String>.shouldApplyFocus(selection: "b", coordinator: coordinator) == false)
    }

    @Test("applyFocus reports unresolved only when there is no window or list, not when it declines")
    func applyFocusResolution() {
        #expect(ListFocusView<String>.applyFocus(from: NSView()) == false)

        let fixture = makeFixture()
        let button = NSButton()
        fixture.window.contentView?.addSubview(button)
        _ = fixture.window.makeFirstResponder(button)
        #expect(ListFocusView<String>.applyFocus(from: fixture.background) == true)
        #expect(fixture.window.firstResponder === button)
    }

    @Test("applyFocus promotes the outline view when nothing but the window itself is focused")
    func applyFocusPromotesFromWindow() {
        let fixture = makeFixture()
        _ = fixture.window.makeFirstResponder(nil) // first responder falls back to the window itself

        _ = ListFocusView<String>.applyFocus(from: fixture.background)

        #expect(fixture.window.firstResponder === fixture.detailOutline)
    }

    @Test("applyFocus does not steal focus from an already-focused non-text control")
    func applyFocusLeavesOtherControlsAlone() {
        let fixture = makeFixture()
        let button = NSButton()
        fixture.window.contentView?.addSubview(button)
        _ = fixture.window.makeFirstResponder(button)

        _ = ListFocusView<String>.applyFocus(from: fixture.background)

        #expect(fixture.window.firstResponder === button)
    }

    @Test("applyFocus is a no-op when the outline view is already first responder")
    func applyFocusNoOpWhenAlreadyFocused() {
        let fixture = makeFixture()
        _ = fixture.window.makeFirstResponder(fixture.detailOutline)

        _ = ListFocusView<String>.applyFocus(from: fixture.background)

        #expect(fixture.window.firstResponder === fixture.detailOutline)
    }
}
#endif
