import SwiftUI

struct MenuDayStripView: View {
    @Binding var selectedDay: Weekday
    let today: Weekday
    let plannedSlots: (Weekday) -> Set<MealSlot>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.allCases) { day in
                dayCell(day)
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
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    private func dayCell(_ day: Weekday) -> some View {
        let isSelected = day == selectedDay
        let isToday = day == today
        let planned = plannedSlots(day)
        return Button { select(day) } label: {
            VStack(spacing: 6) {
                Text(day.initial)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Palette.onAccent : (isToday ? Palette.accent : Palette.ink))
                HStack(spacing: 3) {
                    ForEach(MealSlot.allCases, id: \.self) { slot in
                        if planned.contains(slot) {
                            Circle().frame(width: 5, height: 5)
                        } else {
                            Circle().strokeBorder(lineWidth: 1).frame(width: 5, height: 5)
                        }
                    }
                }
                .foregroundStyle(isSelected ? Palette.onAccent : Palette.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Palette.accent : Color.clear, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.displayName), \(planned.count) de \(MealSlot.allCases.count) planificadas")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("menuDay-\(day.rawValue)")
    }

    private func select(_ day: Weekday) {
        withAnimation(.spring(duration: 0.3)) { selectedDay = day }
    }

    private func shift(_ offset: Int) {
        let raw = (selectedDay.rawValue - 1 + offset + 7) % 7 + 1
        if let day = Weekday(rawValue: raw) { select(day) }
    }
}

#Preview {
    @Previewable @State var day = Weekday.thursday
    MenuDayStripView(selectedDay: $day, today: .thursday) { $0 == .monday ? [.lunch] : [] }
        .padding()
}
