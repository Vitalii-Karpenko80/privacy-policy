import Foundation

/// The structured result the AI returns for a single voice command.
///
/// This is the contract between the LLM and the app: the model returns **only**
/// this JSON shape, and Swift validates it and performs the actual actions.
/// See ТЗ §7.
struct ParsedIntent: Codable, Equatable {
    var events: [ParsedEvent] = []
    var tasks: [ParsedTask] = []
    var contacts: [ParsedContact] = []
    var notes: [ParsedNote] = []

    var isEmpty: Bool {
        events.isEmpty && tasks.isEmpty && contacts.isEmpty && notes.isEmpty
    }
}

struct ParsedEvent: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    /// ISO calendar date, `yyyy-MM-dd`.
    var date: String?
    /// 24h clock time, `HH:mm`.
    var time: String?
    var notes: String?
    /// Minutes before the event to fire an alarm (e.g. 60 = "за час").
    var reminderMinutes: Int?

    private enum CodingKeys: String, CodingKey {
        case title, date, time, notes, reminderMinutes
    }
}

struct ParsedTask: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    /// Free-form relation such as `before_event`, `today`, `tomorrow`.
    var dueRelation: String?
    var dueDate: String?
    var dueTime: String?

    private enum CodingKeys: String, CodingKey {
        case title, dueRelation, dueDate, dueTime
    }
}

struct ParsedContact: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String

    private enum CodingKeys: String, CodingKey { case name }
}

struct ParsedNote: Codable, Equatable, Identifiable {
    var id = UUID()
    var text: String

    private enum CodingKeys: String, CodingKey { case text }
}
