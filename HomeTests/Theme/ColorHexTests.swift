import Testing
import SwiftUI
@testable import Home

@MainActor
struct ColorHexTests {
    @Test func parsesSixDigitHex() {
        #expect(Color(hex: "FF7333") != nil)
    }

    @Test func roundTripsThroughHex() {
        #expect(Color(hex: "FF7333")?.toHex() == "FF7333")
    }

    @Test func toleratesLeadingHashAndLowercase() {
        #expect(Color(hex: "#ff7333")?.toHex() == "FF7333")
    }

    @Test func rejectsMalformedHex() {
        #expect(Color(hex: "nope") == nil)
        #expect(Color(hex: "FFF") == nil)
    }
}
