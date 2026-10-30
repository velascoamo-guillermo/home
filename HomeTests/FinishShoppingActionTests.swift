import Testing
@testable import Casita

@Suite @MainActor struct FinishShoppingActionTests {
    @Test func hiddenWhenNothingChecked() {
        #expect(!FinishShoppingAction(count: 0).isVisible)
    }

    @Test func visibleWhenSomethingChecked() {
        #expect(FinishShoppingAction(count: 1).isVisible)
    }

    @Test func titleShowsCount() {
        #expect(FinishShoppingAction(count: 3).title == "Done · 3")
    }

    @Test func accessibilityLabelKeepsCountInParentheses() {
        #expect(FinishShoppingAction(count: 1).accessibilityLabel == "Finish shopping (1)")
    }

    @Test func negativeCountClampsToHidden() {
        #expect(!FinishShoppingAction(count: -2).isVisible)
    }
}

@Suite @MainActor struct FinishShoppingPhaseTests {
    @Test func beginOnlyFromIdle() {
        var phase = FinishShoppingAction.Phase.idle
        let first = phase.begin()
        #expect(first)
        #expect(phase == .finishing)
        let second = phase.begin()
        #expect(!second)
        #expect(phase == .finishing)
    }

    @Test func succeedShowsConfirmationThenDismissReturnsToIdle() {
        var phase = FinishShoppingAction.Phase.idle
        _ = phase.begin()
        phase.succeed()
        #expect(phase == .confirmed)
        phase.dismissConfirmation()
        #expect(phase == .idle)
    }

    @Test func failureReturnsToIdleSoUserCanRetry() {
        var phase = FinishShoppingAction.Phase.idle
        _ = phase.begin()
        phase.fail()
        #expect(phase == .idle)
        let retry = phase.begin()
        #expect(retry)
    }

    @Test func dismissIsIgnoredWhileFinishing() {
        var phase = FinishShoppingAction.Phase.finishing
        phase.dismissConfirmation()
        #expect(phase == .finishing)
    }

    @Test func disabledWhileFinishing() {
        #expect(FinishShoppingAction(count: 2, phase: .idle).isEnabled)
        #expect(!FinishShoppingAction(count: 2, phase: .finishing).isEnabled)
    }

    @Test func confirmationStaysVisibleWithZeroChecked() {
        let a = FinishShoppingAction(count: 0, phase: .confirmed)
        #expect(a.isVisible)
        #expect(a.title == "Done ✓")
        #expect(!a.isEnabled)
    }

    @Test func inputLabelsIncludeVisibleWord() {
        #expect(FinishShoppingAction(count: 3).inputLabels.contains("Done"))
    }
}
