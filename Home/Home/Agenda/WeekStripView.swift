import SwiftUI

struct WeekStripView: View {
    @Binding var selectedDay: Date
    let today: Date
    let dotCount: (Date) -> Int

    private let calendar = Calendar.current

    var body: some View {
        let days = AgendaWeek.days(containing: selectedDay, calendar: calendar)
        VStack(spacing: 8) {
            HStack {
                Button("Previous week", systemImage: "chevron.left") { shift(-1) }
                    .labelStyle(.iconOnly)
                Spacer()
                Text(days.first ?? selectedDay, format: .dateTime.month(.wide).year())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !days.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
                    Button("Today") { select(today) }
                        .font(.subheadline.weight(.semibold))
                }
                Button("Next week", systemImage: "chevron.right") { shift(1) }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)

            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(12)
        .background(Palette.surface, in: .rect(cornerRadius: 20))
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                shift(value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let count = dotCount(day)
        return Button { select(day) } label: {
            VStack(spacing: 4) {
                Text(day, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Palette.onAccent : Palette.inkSecondary)
                Text(day, format: .dateTime.day())
                    .font(.headline)
                    .foregroundStyle(isSelected ? Palette.onAccent : (isToday ? Palette.accent : Palette.ink))
                HStack(spacing: 2) {
                    ForEach(0..<min(count, 3), id: \.self) { _ in
                        Circle().frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
                .foregroundStyle(isSelected ? Palette.onAccent : Palette.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Palette.accent : Color.clear, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(day: day, count: count))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("agendaDay-\(AgendaWeek.dayID(day, calendar: calendar))")
    }

    private func select(_ day: Date) {
        withAnimation(.spring(duration: 0.3)) {
            selectedDay = calendar.startOfDay(for: day)
        }
    }

    private func shift(_ weeks: Int) {
        select(AgendaWeek.shifted(selectedDay, weeks: weeks, calendar: calendar))
    }

    private static func accessibilityLabel(day: Date, count: Int) -> String {
        "\(day.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(count) item\(count == 1 ? "" : "s")"
    }
}
