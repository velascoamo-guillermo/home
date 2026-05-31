// HomeTests/ExtractionServiceTests.swift
import Testing
import Foundation
@testable import Home

@Suite("ExtractionService") @MainActor struct ExtractionServiceTests {

    @Test("parses well-formed Claude JSON response")
    func parseWellFormed() throws {
        let json = """
        {
          "visitDate": "2025-03-15",
          "diagnosis": "Mild otitis externa",
          "testResults": {"WBC": "6.5 K/uL", "RBC": "7.2 M/uL"},
          "medications": ["Otomax otic suspension", "Apoquel 16mg"],
          "recommendations": "Follow up in 2 weeks if no improvement."
        }
        """
        let result = try ExtractionService.parseResponse(json)
        #expect(result.diagnosis == "Mild otitis externa")
        #expect(result.medications.count == 2)
        #expect(result.testResults["WBC"] == "6.5 K/uL")
        #expect(result.recommendations == "Follow up in 2 weeks if no improvement.")
    }

    @Test("returns nil visitDate when missing from response")
    func missingDate() throws {
        let json = """
        {
          "visitDate": null,
          "diagnosis": "Healthy",
          "testResults": {},
          "medications": [],
          "recommendations": ""
        }
        """
        let result = try ExtractionService.parseResponse(json)
        #expect(result.visitDate == nil)
    }

    @Test("buildPrompt includes pet name")
    func promptIncludesPetName() {
        let prompt = ExtractionService.buildPrompt(petName: "Luna")
        #expect(prompt.contains("Luna"))
    }

    @Test("buildPrompt contains required JSON schema keys")
    func promptContainsSchemaKeys() {
        let prompt = ExtractionService.buildPrompt(petName: "Buddy")
        #expect(prompt.contains("visitDate"))
        #expect(prompt.contains("diagnosis"))
        #expect(prompt.contains("medications"))
        #expect(prompt.contains("testResults"))
        #expect(prompt.contains("recommendations"))
    }

    @Test("parseResponse throws parseError on invalid JSON")
    func throwsOnInvalidJSON() {
        #expect(throws: ExtractionError.self) {
            try ExtractionService.parseResponse("not json at all")
        }
    }

    @Test("parseResponse parses visitDate string to Date")
    func parsesVisitDate() throws {
        let json = """
        {
          "visitDate": "2024-08-20",
          "diagnosis": "Healthy",
          "testResults": {},
          "medications": [],
          "recommendations": ""
        }
        """
        let result = try ExtractionService.parseResponse(json)
        let date = try #require(result.visitDate)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let components = cal.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2024)
        #expect(components.month == 8)
        #expect(components.day == 20)
    }

    @Test("parseResponse returns empty collections when fields absent")
    func defaultsWhenFieldsAbsent() throws {
        let json = """
        {
          "visitDate": null
        }
        """
        let result = try ExtractionService.parseResponse(json)
        #expect(result.diagnosis == "")
        #expect(result.medications.isEmpty)
        #expect(result.testResults.isEmpty)
        #expect(result.recommendations == "")
    }
}
