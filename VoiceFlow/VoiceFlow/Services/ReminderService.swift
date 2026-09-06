import Foundation
import EventKit

/// Creates reminders (tasks) via EventKit (ТЗ §13).
struct ReminderService {
    let store: EKEventStore

    /// Creates an `EKReminder`. When the task is due *before an event*, the event's
    /// start date is passed in so the due date can be derived.
    @discardableResult
    func createReminder(from parsed: ParsedTask, relatedEventStart: Date? = nil) throws -> String {
        let reminder = EKReminder(eventStore: store)
        reminder.title = parsed.title
        reminder.calendar = store.defaultCalendarForNewReminders()

        if let due = dueDate(for: parsed, relatedEventStart: relatedEventStart) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due
            )
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }

        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    private func dueDate(for parsed: ParsedTask, relatedEventStart: Date?) -> Date? {
        if let explicit = DateResolver.date(dateString: parsed.dueDate, timeString: parsed.dueTime),
           parsed.dueDate != nil {
            return explicit
        }
        switch parsed.dueRelation {
        case "before_event":
            // An hour before the related event, when we know it.
            return relatedEventStart?.addingTimeInterval(-3600)
        case "today":
            return DateResolver.date(dateString: nil, timeString: parsed.dueTime)
        case "tomorrow":
            return Calendar.current.date(byAdding: .day, value: 1, to:
                DateResolver.date(dateString: nil, timeString: parsed.dueTime) ?? .now)
        default:
            return nil
        }
    }
}
