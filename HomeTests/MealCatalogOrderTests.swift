import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct MealCatalogOrderTests {
    private func entry(for meal: Meal, updatedAt: Date) -> MenuEntry {
        MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: meal.id, updatedAt: updatedAt)
    }

    @Test func recentsOrderedByMostRecentAssignment() {
        let a = Meal(title: "Arroz")
        let b = Meal(title: "Burritos")
        let old = Date(timeIntervalSince1970: 1_000)
        let new = Date(timeIntervalSince1970: 2_000)
        let result = MealCatalogOrder.split(
            meals: [a, b],
            entries: [entry(for: a, updatedAt: old), entry(for: b, updatedAt: new)])
        #expect(result.recents.map(\.id) == [b.id, a.id])
        #expect(result.rest.isEmpty)
    }

    @Test func recentsCappedAtLimit() {
        let meals = (0..<7).map { Meal(title: "Meal \($0)") }
        let entries = meals.enumerated().map { i, m in
            entry(for: m, updatedAt: Date(timeIntervalSince1970: Double(i)))
        }
        let result = MealCatalogOrder.split(meals: meals, entries: entries)
        #expect(result.recents.count == 5)
        #expect(result.rest.count == 2)
    }

    @Test func neverAssignedMealsStayInRestAlphabetically() {
        let z = Meal(title: "Zanahoria")
        let a = Meal(title: "Arroz")
        let used = Meal(title: "Burritos")
        let result = MealCatalogOrder.split(
            meals: [z, a, used],
            entries: [entry(for: used, updatedAt: .now)])
        #expect(result.recents.map(\.id) == [used.id])
        #expect(result.rest.map(\.title) == ["Arroz", "Zanahoria"])
    }

    @Test func emptyEntriesMeansAllAlphabeticalRest() {
        let result = MealCatalogOrder.split(
            meals: [Meal(title: "B"), Meal(title: "A")], entries: [])
        #expect(result.recents.isEmpty)
        #expect(result.rest.map(\.title) == ["A", "B"])
    }

    @Test func blankTitleMealsExcluded() {
        let blank = Meal(title: "")
        let ok = Meal(title: "A")
        let result = MealCatalogOrder.split(meals: [blank, ok], entries: [])
        #expect(result.rest.map(\.id) == [ok.id])
    }

    @Test func entryForUnknownMealIgnored() {
        let m = Meal(title: "A")
        let ghost = MenuEntry(dayOfWeek: 1, slot: .dinner, mealId: UUID())
        let result = MealCatalogOrder.split(meals: [m], entries: [ghost])
        #expect(result.recents.isEmpty)
        #expect(result.rest.map(\.id) == [m.id])
    }
}
