import Foundation

/// Converts the AI's `yyyy-MM-dd` / `HH:mm` strings into concrete `Date`s.
///
/// The LLM returns the structure; Swift owns the actual date math and defaults.
enum DateResolver {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Combines a date string and a time string into a `Date`.
    /// Falls back to `now`'s day and a 09:00 default time when parts are missing.
    static func date(dateString: String?, timeString: String?, now: Date = .now) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let baseDay: Date
        if let dateString, let parsed = dateFormatter.date(from: dateString) {
            baseDay = parsed
        } else {
            baseDay = now
        }

        var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
        let (hour, minute) = time(from: timeString)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    private static func time(from timeString: String?) -> (Int, Int) {
        guard let timeString else { return (9, 0) }
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return (9, 0) }
        return (min(max(parts[0], 0), 23), min(max(parts[1], 0), 59))
    }
}
