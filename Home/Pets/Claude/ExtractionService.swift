// Home/Pets/Claude/ExtractionService.swift
import Foundation

struct ExtractionResult {
    var visitDate: Date?
    var diagnosis: String
    var testResults: [String: String]
    var medications: [String]
    var recommendations: String
}

enum ExtractionError: LocalizedError {
    case networkError(Error)
    case invalidResponse(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .networkError(let e):    return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let c): return "Extraction failed (status \(c))."
        case .parseError:             return "Could not parse the document. Try a clearer scan."
        }
    }
}

enum ExtractionService {

    static func buildPrompt(petName: String) -> String {
        """
        You are a veterinary records assistant. Analyze the attached document for \(petName) and extract the following information. Respond with ONLY valid JSON matching this exact schema — no markdown, no extra text:

        {
          "visitDate": "YYYY-MM-DD or null",
          "diagnosis": "string",
          "testResults": {"test name": "value"},
          "medications": ["string"],
          "recommendations": "string"
        }

        If a field is not present in the document, use null for dates and empty string/array for others.
        """
    }

    static func parseResponse(_ json: String) throws -> ExtractionResult {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExtractionError.parseError
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var visitDate: Date? = nil
        if let dateStr = obj["visitDate"] as? String { visitDate = dateFormatter.date(from: dateStr) }
        let diagnosis = obj["diagnosis"] as? String ?? ""
        let testResults = obj["testResults"] as? [String: String] ?? [:]
        let medications = obj["medications"] as? [String] ?? []
        let recommendations = obj["recommendations"] as? String ?? ""
        return ExtractionResult(visitDate: visitDate, diagnosis: diagnosis,
                                testResults: testResults, medications: medications,
                                recommendations: recommendations)
    }
}
