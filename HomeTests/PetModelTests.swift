// HomeTests/PetModelTests.swift
import Testing
import Foundation
@testable import Home

// MARK: - Pet Codable

@Suite("Pet Codable") struct PetCodableTests {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("round-trips pet without birthday")
    func roundTripNoBirthday() throws {
        let pet = Pet(name: "Luna", type: "cat", breed: "siamese")
        let data = try encoder.encode(pet)
        let decoded = try decoder.decode(Pet.self, from: data)
        #expect(decoded.id == pet.id)
        #expect(decoded.name == "Luna")
        #expect(decoded.birthday == nil)
    }

    @Test("round-trips pet with birthday preserved as yyyy-MM-dd")
    func roundTripWithBirthday() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let birthday = cal.date(from: DateComponents(year: 2020, month: 6, day: 15))!
        let pet = Pet(name: "Rex", type: "dog", breed: "lab", birthday: birthday)

        let data = try encoder.encode(pet)
        let decoded = try decoder.decode(Pet.self, from: data)

        let components = cal.dateComponents([.year, .month, .day], from: try #require(decoded.birthday))
        #expect(components.year == 2020)
        #expect(components.month == 6)
        #expect(components.day == 15)
    }

    @Test("encodes birthday as yyyy-MM-dd string in JSON")
    func birthdayStringFormat() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let birthday = cal.date(from: DateComponents(year: 2021, month: 1, day: 3))!
        let pet = Pet(name: "Mochi", type: "cat", breed: "persian", birthday: birthday)

        let data = try encoder.encode(pet)
        let json = try #require(try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["birthday"] as? String == "2021-01-03")
    }

    @Test("encodes null when birthday is nil")
    func birthdayNullWhenNil() throws {
        let pet = Pet(name: "Ghost", type: "cat", breed: "maine coon")
        let data = try encoder.encode(pet)
        let json = try #require(try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["birthday"] is NSNull)
    }
}

// MARK: - PetFile.displayName

@Suite("PetFile.displayName") struct PetFileDisplayNameTests {

    @Test("returns last path component from storagePath")
    func lastComponent() {
        let file = PetFile(
            petId: UUID(), storagePath: "abc123/somefile.pdf",
            sourceType: .document, linkedToType: "standalone", linkedToId: nil, createdAt: .now
        )
        #expect(file.displayName == "somefile.pdf")
    }

    @Test("returns storagePath when it has no path separator")
    func noSeparator() {
        let file = PetFile(
            petId: UUID(), storagePath: "justfilename.jpg",
            sourceType: .photo, linkedToType: "standalone", linkedToId: nil, createdAt: .now
        )
        #expect(file.displayName == "justfilename.jpg")
    }
}

// MARK: - EventCategory

@Suite("EventCategory") struct EventCategoryTests {

    @Test("icon matches category", arguments: [
        (EventCategory.vaccine,    "syringe"),
        (.grooming,                "scissors"),
        (.medication,              "pill"),
        (.weight,                  "scalemass"),
        (.other,                   "note.text"),
    ])
    func icon(category: EventCategory, expected: String) {
        #expect(category.icon == expected)
    }

    @Test("label is rawValue capitalized", arguments: EventCategory.allCases)
    func label(category: EventCategory) {
        #expect(category.label == category.rawValue.capitalized)
    }
}
