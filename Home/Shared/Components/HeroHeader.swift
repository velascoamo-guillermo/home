import SwiftUI

struct HeroHeader: View {
    let label: String
    let value: Int
    let unit: String
    let subline: String?

    var body: some View {
        VStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(value, format: .number)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accent)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.title3)
            }
            .accessibilityElement(children: .combine)
            if let subline {
                Text(subline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HeroHeader(
        label: "Good morning · Friday, September 12",
        value: 3,
        unit: "tasks today",
        subline: "2 to buy"
    )
}
