import SwiftUI

struct ChipGroup<Item: Identifiable & Hashable>: View {
    let items: [Item]
    private let fill: Color
    private let title: (Item) -> String
    private let systemImage: (Item) -> String?
    private let selection: Binding<Item?>
    private let allowsDeselection: Bool

    init(
        items: [Item],
        selection: Binding<Item>,
        fill: Color,
        title: @escaping (Item) -> String,
        systemImage: @escaping (Item) -> String? = { _ in nil }
    ) {
        self.items = items
        self.fill = fill
        self.title = title
        self.systemImage = systemImage
        self.allowsDeselection = false
        self.selection = Binding<Item?>(
            get: { selection.wrappedValue },
            set: { newValue in
                guard let newValue else { return }
                selection.wrappedValue = newValue
            }
        )
    }

    init(
        items: [Item],
        selection: Binding<Item?>,
        fill: Color,
        title: @escaping (Item) -> String,
        systemImage: @escaping (Item) -> String? = { _ in nil }
    ) {
        self.items = items
        self.fill = fill
        self.title = title
        self.systemImage = systemImage
        self.allowsDeselection = true
        self.selection = selection
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                Chip(
                    title: title(item),
                    systemImage: systemImage(item),
                    fill: fill,
                    isSelected: selection.wrappedValue == item,
                    action: { tap(item) }
                )
            }
        }
    }

    private func tap(_ item: Item) {
        if allowsDeselection {
            selection.wrappedValue = ChipSelection.next(current: selection.wrappedValue, tapped: item)
        } else {
            let current = selection.wrappedValue ?? item
            let next: Item = ChipSelection.next(current: current, tapped: item)
            selection.wrappedValue = next
        }
    }
}

/// Wraps its children left-to-right, top-to-bottom, breaking to a new row when the
/// next child would overflow the proposed width. Layout's requirements are nonisolated,
/// so this type must stay nonisolated too (a MainActor-default struct wouldn't conform).
nonisolated struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 10_000
        let rows = makeRows(subviews: subviews, maxWidth: maxWidth)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let rows = makeRows(subviews: subviews, maxWidth: maxWidth)
        var y = bounds.minY
        var index = 0
        for row in rows {
            var x = bounds.minX
            for _ in row.indices {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }

    private func makeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let additionalWidth = current.indices.isEmpty ? size.width : size.width + spacing

            if !current.indices.isEmpty && current.width + additionalWidth > maxWidth {
                rows.append(current)
                current = Row()
            }

            current.indices.append(index)
            current.width += current.indices.count == 1 ? size.width : size.width + spacing
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }

        return rows
    }
}

#Preview {
    struct PreviewItem: Identifiable, Hashable {
        let id: String
        var name: String { id }
    }

    struct Wrapper: View {
        @State private var selection: PreviewItem?
        let items = ["Dogs", "Cats", "Birds", "Reptiles", "Small mammals"].map(PreviewItem.init)

        var body: some View {
            ChipGroup(items: items, selection: $selection, fill: Palette.pets, title: \.name)
                .padding()
        }
    }

    return Wrapper()
}
