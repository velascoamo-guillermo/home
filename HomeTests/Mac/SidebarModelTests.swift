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

    @Test("emoji and combining marks do not split grapheme clusters when truncated")
    func emojiGraphemeTruncation() {
        // Test 1: 12 ASCII characters followed by emoji family cluster as the 13th character
        let emojiPet1 = Pet(name: "AAAAAAAAAAAA👩‍👩‍👧‍👦 and more text", type: "Cat", breed: "Tabby")
        let title1 = SidebarModel.title(for: .pet(emojiPet1.id), pets: [emojiPet1])

        #expect(title1 == "AAAAAAAAAAAA👩‍👩‍👧‍👦…", "title should be first 13 characters plus ellipsis")
        #expect(title1.count == SidebarModel.maxTitleLength, "title must be exactly maxTitleLength")
        #expect(title1.dropLast().last == "👩‍👩‍👧‍👦", "last kept character must be the complete emoji cluster")

        // Test 2: 12 ASCII characters followed by combining accent (é as e\u{0301})
        let emojiPet2 = Pet(name: "AAAAAAAAAAAA" + "e\u{0301}" + " and more text", type: "Dog", breed: "Lab")
        let title2 = SidebarModel.title(for: .pet(emojiPet2.id), pets: [emojiPet2])

        let expected2 = "AAAAAAAAAAAA" + "e\u{0301}" + "…"
        #expect(title2 == expected2, "title should preserve combining accent as a single character")
        #expect(title2.count == SidebarModel.maxTitleLength, "title must be exactly maxTitleLength")
        #expect(title2.dropLast().last == Character("e\u{0301}"), "last kept character must be the combining mark cluster")
    }

    @Test("pet row sorting is deterministic and independent of input order")
    func petRowDeterminism() {
        let maxUUID1 = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let maxUUID2 = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let bellaUUID1 = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let bellaUUID2 = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let cafeUUID1 = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
        let cafeUUID2 = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!

        let sameName1 = Pet(id: maxUUID1, name: "Max", type: "Dog", breed: "Lab")
        let sameName2 = Pet(id: maxUUID2, name: "Max", type: "Cat", breed: "Siamese")
        let caseVariant1 = Pet(id: bellaUUID1, name: "bella", type: "Dog", breed: "Poodle")
        let caseVariant2 = Pet(id: bellaUUID2, name: "Bella", type: "Cat", breed: "Tabby")
        let accentVariant1 = Pet(id: cafeUUID1, name: "Café", type: "Dog", breed: "Dachshund")
        let accentVariant2 = Pet(id: cafeUUID2, name: "Cafe", type: "Cat", breed: "Persian")

        // Sort with different input orders; stable sort preserves input order for ties with identical names
        let order1 = SidebarModel.petRows([sameName1, sameName2, caseVariant1, caseVariant2, accentVariant1, accentVariant2]).map(\.id)
        let order2 = SidebarModel.petRows([accentVariant2, caseVariant2, sameName2, accentVariant1, caseVariant1, sameName1]).map(\.id)

        // For "Max"/"Max" pair: input order1 is [sameName1, sameName2]=[A,B], order2 is [..., sameName2, ..., sameName1]=[B,...,A]
        #expect(order1 == [bellaUUID1, bellaUUID2, cafeUUID2, cafeUUID1, maxUUID1, maxUUID2], "order1 preserves input order [A,B] for Max tie")
        #expect(order2 == [bellaUUID1, bellaUUID2, cafeUUID2, cafeUUID1, maxUUID2, maxUUID1], "order2 preserves input order [B,A] for Max tie")

        // Repeated calls with same input order return consistent order
        let order3 = SidebarModel.petRows([sameName1, sameName2, caseVariant1, caseVariant2, accentVariant1, accentVariant2]).map(\.id)
        #expect(order1 == order3, "repeated calls should return same order")
    }

    @Test("JSON encoding is stable for window state restoration")
    func goldenEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        // Encode .today
        let todayItem = SidebarItem.today
        let todayData = try encoder.encode(todayItem)
        let todayJSON = String(data: todayData, encoding: .utf8)!
        #expect(todayJSON == "{\"today\":{}}", "today should encode as {\"today\":{}}")

        // Decode and verify round-trip
        let decodedToday = try JSONDecoder().decode(SidebarItem.self, from: todayData)
        #expect(decodedToday == .today, "today should round-trip through JSON")

        // Encode .pet with fixed UUID
        let fixedUUID = UUID(uuidString: "12345678-1234-5678-1234-567812345678")!
        let petItem = SidebarItem.pet(fixedUUID)
        let petData = try encoder.encode(petItem)
        let petJSON = String(data: petData, encoding: .utf8)!

        // Assert exact JSON string for .pet encoding
        #expect(petJSON == "{\"pet\":{\"_0\":\"12345678-1234-5678-1234-567812345678\"}}", "pet should encode with exact structure")

        // Decode and verify round-trip
        let decodedPet = try JSONDecoder().decode(SidebarItem.self, from: petData)
        #expect(decodedPet == petItem, "pet should round-trip through JSON")
    }
}
#endif
