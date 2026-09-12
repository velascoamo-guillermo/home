import Testing
import Foundation
@testable import Casita

@Suite("HouseholdTask coding") struct HouseholdTaskCodingTests {

    private func decode(_ json: String) throws -> HouseholdTask {
        try JSONDecoder().decode(HouseholdTask.self, from: Data(json.utf8))
    }

    private let base = """
        "id":"00000000-0000-0000-0000-000000000001","title":"Filter",
        "interval_days":30,"next_due_date":0,"notes":"","updated_at":0
        """

    @Test func decodesSectionKey() throws {
        let t = try decode("{\(base),\"section\":\"plumbing\"}")
        #expect(t.section == .plumbing)
    }

    @Test func decodesLegacyIcon() throws {
        let t = try decode("{\(base),\"icon\":\"drop\"}")
        #expect(t.section == .plumbing)
    }

    @Test func unknownLegacyIconFallsBackToGeneral() throws {
        let t = try decode("{\(base),\"icon\":\"pawprint\"}")
        #expect(t.section == .general)
    }

    @Test func sectionWinsOverLegacyIcon() throws {
        let t = try decode("{\(base),\"section\":\"garden\",\"icon\":\"drop\"}")
        #expect(t.section == .garden)
    }

    @Test func missingBothDefaultsToGeneral() throws {
        let t = try decode("{\(base)}")
        #expect(t.section == .general)
    }

    @Test func encodesSectionNeverIcon() throws {
        let t = HouseholdTask(title: "x", section: .kitchen, intervalDays: 7, nextDueDate: .now)
        let data = try JSONEncoder().encode(t)
        let obj = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["section"] as? String == "kitchen")
        #expect(obj["icon"] == nil)
    }
}
