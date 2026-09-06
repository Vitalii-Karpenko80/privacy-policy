import Foundation

/// Wrappers that add an include/exclude toggle (and resolved contact matches)
/// to the parsed objects shown on the Review screen.
struct EventReviewItem: Identifiable {
    let id = UUID()
    var event: ParsedEvent
    var include = true
}

struct TaskReviewItem: Identifiable {
    let id = UUID()
    var task: ParsedTask
    var include = true
}

struct ContactReviewItem: Identifiable {
    let id = UUID()
    var parsed: ParsedContact
    var candidates: [ContactMatch]
    var selected: ContactMatch?
    var include = true

    var isFound: Bool { selected != nil }
}

struct NoteReviewItem: Identifiable {
    let id = UUID()
    var note: ParsedNote
    var include = true
}
