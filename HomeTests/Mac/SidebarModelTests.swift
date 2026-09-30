#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("SidebarModel") @MainActor struct SidebarModelTests {
    private let luna = Pet(name: "Luna", type: "Dog", breed: "Golden")
    private let bigotes = Pet(name: "Señor Bigotes de la Mancha", type: "Cat", breed: "Tabby")
    private let alba = Pet(name: "alba", type: "Cat", breed: "Siamese")

    @Test("household rows keep the spec's order")
    func householdOrder() {
        #expect(SidebarItem.household == [.tasks, .shopping, .stock, .meals, .budget])
    }

    @Test("pet rows sort by name, case- and accent-insensitively")
    func petOrder() {
        #expect(SidebarModel.petRows([luna, bigotes, alba]).map(\.name) == ["alba", "Luna", "Señor Bigotes de la Mancha"])
    }

    @Test("every fixed title is under 15 characters and is not the app name")
    func fixedTitles() {
        for item in [SidebarItem.today] + SidebarItem.household {
            let title = SidebarModel.title(for: item, pets: [])
            #expect(title.count < 15, "\(title)")
            #expect(title != "Casita")
        }
    }

    @Test("a long pet name is truncated with an ellipsis to stay under 15 characters")
    func longPetTitle() {
        let title = SidebarModel.title(for: .pet(bigotes.id), pets: [bigotes])
        #expect(title == "Señor Bigotes…")
        #expect(title.count == SidebarModel.maxTitleLength)
    }

    @Test("a short pet name is used as is")
    func shortPetTitle() {
        #expect(SidebarModel.title(for: .pet(luna.id), pets: [luna]) == "Luna")
    }

    @Test("a pet that no longer exists resolves to Today")
    func stalePetResolvesToToday() {
        #expect(SidebarModel.resolve(.pet(UUID()), pets: [luna]) == .today)
        #expect(SidebarModel.resolve(.pet(luna.id), pets: [luna]) == .pet(luna.id))
        #expect(SidebarModel.resolve(.budget, pets: []) == .budget)
    }

    @Test("a missing pet's title falls back to Pets")
    func stalePetTitle() {
        #expect(SidebarModel.title(for: .pet(UUID()), pets: []) == "Pets")
    }

    @Test("widget and in-app deep links map to sidebar rows")
    func deepLinks() {
        let pets = [luna, alba]
        #expect(SidebarModel.item(for: AppRouter.route(host: "home"), pets: pets) == .today)
        #expect(SidebarModel.item(for: AppRouter.route(host: "shopping"), pets: pets) == .shopping)
        #expect(SidebarModel.item(for: AppRouter.route(host: "meals"), pets: pets) == .meals)
        #expect(SidebarModel.item(for: AppRouter.route(host: "budget"), pets: pets) == .budget)
        #expect(SidebarModel.item(for: AppRouter.route(host: "pets"), pets: pets) == .pet(alba.id))
        #expect(SidebarModel.item(for: AppRouter.route(host: "pets"), pets: []) == .today)
        #expect(SidebarModel.item(for: AppRouter.route(host: "search"), pets: pets) == .today)
        #expect(SidebarModel.item(for: AppRouter.route(host: "nonsense"), pets: pets) == .today)
    }

    @Test("the selection round-trips through Codable for window restoration")
    func codable() throws {
        let item = SidebarItem.pet(luna.id)
        let data = try JSONEncoder().encode(item)
        #expect(try JSONDecoder().decode(SidebarItem.self, from: data) == item)
    }
}
#endif
