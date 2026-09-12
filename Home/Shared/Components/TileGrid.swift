import SwiftUI

/// A single pastel tile: a filled circle icon over a centered label.
struct Tile: View {
    let title: String
    let systemImage: String
    let fill: Color

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(fill)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.ink)
                }
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A 3-column pastel grid, used by `MenuHubView` to lay out `Tile`s.
struct TileGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            content()
        }
    }
}
