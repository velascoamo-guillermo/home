import SwiftUI

/// Row-sized leading glyph: category colour lives on the circle, the symbol stays `Palette.ink`.
struct CategoryGlyph: View {
    let systemImage: String
    let fill: Color

    init(_ destination: HubDestination) {
        systemImage = destination.systemImage
        fill = destination.fill
    }

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink)
            }
            .accessibilityHidden(true)
    }
}
