import Testing
@testable import Casita

struct WidgetMealSlotLabelTests {

    @Test func lunchSlotReadsComida() {
        let meal = WidgetMeal(slot: "lunch", title: "Pasta", products: [], isShort: false, isEmpty: false)

        #expect(meal.slotLabel == "Comida")
    }

    @Test func dinnerSlotReadsCena() {
        let meal = WidgetMeal(slot: "dinner", title: "Sopa", products: [], isShort: false, isEmpty: false)

        #expect(meal.slotLabel == "Cena")
    }

    @Test func unknownSlotFallsBackToCena() {
        let meal = WidgetMeal(slot: "brunch", title: "Tostadas", products: [], isShort: false, isEmpty: false)

        #expect(meal.slotLabel == "Cena")
    }
}
