import Testing
import Foundation
@testable import Casita

@Suite("SupabaseStore weight entries") @MainActor struct WeightEntryStoreTests {
    @Test("weightEntries(for:) filters by pet and sorts newest first")
    func filterAndSort() {
        let store = SupabaseStore.makeTest()
        let petA = UUID(), petB = UUID()
        let old = WeightEntry(petId: petA, date: .now.addingTimeInterval(-86400), weightKg: 10)
        let new = WeightEntry(petId: petA, date: .now, weightKg: 11)
        let other = WeightEntry(petId: petB, date: .now, weightKg: 5)
        store.weightEntries = [old, other, new]
        #expect(store.weightEntries(for: petA).map(\.weightKg) == [11, 10])
    }
}
