import Foundation
import SwiftData

/// Locally stored note (VoiceFlow's own store — there is no public API to write
/// arbitrary third-party notes into Apple Notes; see ТЗ §14).
@Model
final class VoiceNote {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date
    /// Identifier of a system contact (`CNContact.identifier`), if related.
    var relatedContactID: String?
    /// Identifier of a created calendar event (`EKEvent.eventIdentifier`), if related.
    var relatedEventID: String?

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        relatedContactID: String? = nil,
        relatedEventID: String? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.relatedContactID = relatedContactID
        self.relatedEventID = relatedEventID
    }
}

/// A record of one processed voice command, shown in History (ТЗ §15).
@Model
final class CommandRecord {
    @Attribute(.unique) var id: UUID
    var transcript: String
    var createdAt: Date
    var eventsCount: Int
    var tasksCount: Int
    var notesCount: Int
    /// Names of contacts referenced by this command (for the history summary).
    var contactNames: [String]

    init(
        id: UUID = UUID(),
        transcript: String,
        createdAt: Date = .now,
        eventsCount: Int = 0,
        tasksCount: Int = 0,
        notesCount: Int = 0,
        contactNames: [String] = []
    ) {
        self.id = id
        self.transcript = transcript
        self.createdAt = createdAt
        self.eventsCount = eventsCount
        self.tasksCount = tasksCount
        self.notesCount = notesCount
        self.contactNames = contactNames
    }

    convenience init(transcript: String, intent: ParsedIntent) {
        self.init(
            transcript: transcript,
            eventsCount: intent.events.count,
            tasksCount: intent.tasks.count,
            notesCount: intent.notes.count,
            contactNames: intent.contacts.map(\.name)
        )
    }
}
