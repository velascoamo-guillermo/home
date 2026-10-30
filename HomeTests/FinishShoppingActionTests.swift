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
