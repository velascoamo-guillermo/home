import Testing
import Foundation
@testable import Casita

@Suite("TaskSection coding") struct TaskSectionCodingTests {

    private let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private func decode(_ json: String) throws -> TaskSection {
        try JSONDecoder().decode(TaskSection.self, from: Data(json.utf8))
    }

    @Test func decodesCurrentShape() throws {
        let section = try decode("{\"id\":\"\(id.uuidString)\",\"name\":\"Garage\",\"updated_at\":0}")
        #expect(section.id == id)
        #expect(section.name == "Garage")
    }

    @Test func decodesLegacyPayloadWithIcon() throws {
        let section = try decode(
            "{\"id\":\"\(id.uuidString)\",\"name\":\"Garage\",\"updated_at\":0,\"icon\":\"star\"}")
        #expect(section.name == "Garage")
    }

    @Test func encodesNameNeverIcon() throws {
        let section = TaskSection(id: id, name: "Garage",
                                  updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(section)
        let obj = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(obj.keys) == ["id", "name", "updated_at"])
        #expect(obj["icon"] == nil)
    }

    @Test func encodesDeletedAtWhenSet() throws {
        let section = TaskSection(id: id, name: "Garage",
                                  updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                  deletedAt: Date(timeIntervalSince1970: 1_700_000_100))
        let data = try JSONEncoder().encode(section)
        let obj = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(obj.keys) == ["id", "name", "updated_at", "deleted_at"])
        #expect(obj["icon"] == nil)
    }

    @Test func roundTripsThroughSyncCoders() throws {
        let original = TaskSection(id: id, name: "Garage",
                                   updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoded = try SyncDateCoding.makeDecoder()
            .decode(TaskSection.self, from: try encoder.encode(original))
        #expect(decoded == original)
    }
}
