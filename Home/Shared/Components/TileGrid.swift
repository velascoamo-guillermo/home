import SwiftUI

/// A single pastel tile: a filled circle icon over a centered label.
struct Tile: View {
    let title: String
    let systemImage: String
    let fill: Color
    /// Count bubble on the icon; hidden when nil or zero.
    var badge: Int? = nil
    /// Hidden icons pop in (staggered by `entranceIndex`) when this flips to `true`.
    var isRevealed = true
    var entranceIndex = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRenderedHidden = false

    static let maxStaggeredIndex = 8

    static func entranceDelay(forIndex index: Int) -> Double {
        Double(min(max(index, 0), maxStaggeredIndex)) * 0.05
    }

    private var showsIcon: Bool { (isRevealed && hasRenderedHidden) || reduceMotion }

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
                .overlay(alignment: .topTrailing) {
                    if let badge, badge > 0 {
                        Text(badge, format: .number)
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(Palette.onAccent)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Palette.accent, in: .capsule)
                            .offset(x: 4, y: -4)
                    }
                }
                .scaleEffect(showsIcon ? 1 : 0.4)
                .rotationEffect(showsIcon ? .zero : .degrees(-14))
                .opacity(showsIcon ? 1 : 0)
                .animation(
                    .bouncy(duration: 0.45, extraBounce: 0.1).delay(Self.entranceDelay(forIndex: entranceIndex)),
                    value: showsIcon
                )
                // A tile inserted already revealed would skip the pop-in; show it hidden for one render first.
                .task { hasRenderedHidden = true }
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(title: title, badge: badge))
    }

    static func accessibilityLabel(title: String, badge: Int?) -> String {
        guard let badge, badge > 0 else { return title }
        return "\(title), \(badge)"
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
