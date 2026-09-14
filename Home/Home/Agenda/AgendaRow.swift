import SwiftUI

struct AgendaRow: View {
    let item: AgendaItem
    var onComplete: (() -> Void)? = nil

    var body: some View {
        let row = HStack(spacing: 12) {
            leading
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? Color.red : Palette.inkSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 4)
        .opacity(isDimmed ? 0.5 : 1)

        // Rows with an inner mark-done button (real/overdue tasks) keep their own
        // children so `markDone-<title>` stays independently reachable; everything
        // else has no interactive child, so it reads as a single VoiceOver stop.
        if let label = Self.accessibilityLabel(for: item) {
            row
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
        } else {
            row
        }
    }

    // nil means the row keeps its own children (real/overdue tasks — the
    // mark-done button must stay reachable as its own element).
    static func accessibilityLabel(for item: AgendaItem) -> String? {
        switch item {
        case .task(let task, .projected):
            return "\(task.title), repeats, upcoming"
        case .task(_, .real), .task(_, .overdue):
            return nil
        default:
            guard let subtitle = subtitle(for: item) else { return item.title }
            return "\(item.title), \(subtitle)"
        }
    }

    static func fill(for item: AgendaItem) -> Color {
        switch item {
        case .task:                    Palette.tasks
        case .appointment, .petEvent:  Palette.pets
        case .meal:                    Palette.meals
        case .calendarEvent:           Palette.surface
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch item {
        case .appointment(let appt, _):
            timeText(appt.date)
        case .calendarEvent(let event, let continues) where !event.isAllDay && !continues:
            timeText(event.start)
        default:
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch item {
        case .task(_, .projected):
            EmptyView()
        case .task:
            if let onComplete {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Mark done")
                .accessibilityIdentifier("markDone-\(item.title)")
            }
        case .calendarEvent(let event, _):
            Circle()
                .fill(Color(red: event.calendarColor.red, green: event.calendarColor.green, blue: event.calendarColor.blue))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        default:
            EmptyView()
        }
    }

    private func timeText(_ date: Date) -> some View {
        Text(date, format: .dateTime.hour().minute())
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(Palette.ink)
    }

    private var icon: String {
        switch item {
        case .task:                     "checklist"
        case .petEvent(let event, _):   event.category.icon
        case .meal:                     "fork.knife"
        case .calendarEvent:            "calendar"
        case .appointment:              "stethoscope"
        }
    }

    private var subtitle: String? { Self.subtitle(for: item) }

    private static func subtitle(for item: AgendaItem) -> String? {
        switch item {
        case .task(_, .overdue(let days)):
            return "\(days)d overdue"
        case .task(_, .projected):
            return "Repeats"
        case .task(let task, .real):
            return task.notes.isEmpty ? nil : task.notes
        case .appointment(let appt, let pet):
            return appt.status == .done ? "\(pet.name) · Done" : pet.name
        case .petEvent(let event, let pet):
            return "\(pet.name) · \(event.category.label)"
        case .meal(_, let slot):
            return slot.displayName
        case .calendarEvent(let event, let continues):
            guard continues, !event.isAllDay else { return event.calendarTitle }
            return "\(event.calendarTitle) · until \(event.end.formatted(.dateTime.hour().minute()))"
        }
    }

    private var isOverdue: Bool {
        if case .task(_, .overdue) = item { return true }
        return false
    }

    private var isDimmed: Bool {
        switch item {
        case .task(_, .projected): true
        case .appointment(let appt, _): appt.status == .done
        default: false
        }
    }
}
