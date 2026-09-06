import Foundation
import EventKit

/// Creates and reads calendar events via EventKit (ТЗ §12).
struct CalendarService {
    let store: EKEventStore

    /// Creates an `EKEvent` from a parsed event, attaching an alarm if requested.
    /// Returns the created event identifier.
    @discardableResult
    func createEvent(from parsed: ParsedEvent, defaultDurationMinutes: Int = 60) throws -> String {
        let start = DateResolver.date(dateString: parsed.date, timeString: parsed.time) ?? .now

        let event = EKEvent(eventStore: store)
        event.title = parsed.title
        event.notes = parsed.notes
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(defaultDurationMinutes * 60))
        event.calendar = store.defaultCalendarForNewEvents

        if let minutes = parsed.reminderMinutes {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
        }

        try store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    /// Events for a given day, sorted by start time (used by Home + Contact context).
    func events(on day: Date) -> [EKEvent] {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
}
