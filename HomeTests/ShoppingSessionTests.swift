import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct ShoppingSessionTests {
    private func makeDefaults() -> UserDefaults {
        let name = "shopping-session-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func toggleChecksAndUnchecks() {
        let session = ShoppingSession(defaults: makeDefaults())
        let id = UUID()
        session.toggle(id)
        #expect(session.isChecked(id))
        session.toggle(id)
        #expect(!session.isChecked(id))
    }

    @Test func persistsAcrossInstances() {
        let name = "shopping-session-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let id = UUID()
        ShoppingSession(defaults: defaults).toggle(id)
        #expect(ShoppingSession(defaults: defaults).isChecked(id))
    }

    @Test func prunesOrphanedIds() {
        let session = ShoppingSession(defaults: makeDefaults())
        let keep = UUID()
        let orphan = UUID()
        session.toggle(keep)
        session.toggle(orphan)
        session.prune(validIds: [keep])
        #expect(session.isChecked(keep))
        #expect(!session.isChecked(orphan))
    }

    @Test func pruneSurvivesReload() {
        let name = "shopping-session-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let keep = UUID()
        let orphan = UUID()
        let first = ShoppingSession(defaults: defaults)
        first.toggle(keep)
        first.toggle(orphan)
        first.prune(validIds: [keep])
        let reloaded = ShoppingSession(defaults: defaults)
        #expect(reloaded.isChecked(keep))
        #expect(!reloaded.isChecked(orphan))
    }

    @Test func uncheckRemovesOnlyGivenIds() {
        let session = ShoppingSession(defaults: makeDefaults())
        let bought = UUID()
        let pending = UUID()
        session.toggle(bought)
        session.toggle(pending)
        session.uncheck([bought])
        #expect(!session.isChecked(bought))
        #expect(session.isChecked(pending))
    }

    @Test func quickAddProductUsesShoppingDefaults() {
        let product = ShoppingSession.quickAddProduct(named: "  Leche  ")
        #expect(product?.name == "Leche")
        #expect(product?.icon == "shippingbox")
        #expect(product?.packages == 0)
        #expect(product?.looseUnits == 0)
        #expect(product?.unitsPerPackage == 1)
        #expect(product?.totalUnits == 0)
    }

    @Test func quickAddProductRejectsBlankName() {
        #expect(ShoppingSession.quickAddProduct(named: "   ") == nil)
        #expect(ShoppingSession.quickAddProduct(named: "") == nil)
    }
}
