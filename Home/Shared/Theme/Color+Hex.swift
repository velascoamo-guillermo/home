import SwiftUI
import UIKit

extension Color {
    init?(hex: String) {
        let s = (hex.hasPrefix("#") ? String(hex.dropFirst()) : hex).uppercased()
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        let c = UIColor(self).cgColor.components ?? [0, 0, 0]
        let r = c[0]
        let g = c.count > 1 ? c[1] : c[0]
        let b = c.count > 2 ? c[2] : c[0]
        return String(
            format: "%02X%02X%02X",
            Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded())
        )
    }
}
