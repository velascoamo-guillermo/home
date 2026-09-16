import SwiftUI

struct StockGauge: View {
    let level: StockLevel

    private static let segmentCount = 3

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<Self.segmentCount, id: \.self) { index in
                segment(filled: index < level.filledSegments)
                    .frame(width: 14, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: level)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func segment(filled: Bool) -> some View {
        if level == .out {
            Capsule().stroke(.red, lineWidth: 1.5)
        } else {
            Capsule().fill(filled ? tint : Palette.inkSecondary.opacity(0.25))
        }
    }

    private var tint: Color {
        switch level {
        case .out:    .red
        case .low:    .orange
        case .medium: Palette.accent
        case .full:   .green
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(StockLevel.allCases, id: \.self) { StockGauge(level: $0) }
    }
    .padding()
}
