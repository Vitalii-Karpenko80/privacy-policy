import Foundation

/// Kinds of intent VoiceFlow can extract from a spoken command.
///
/// The MVP handles the first four; the rest are planned (see ТЗ §8).
enum IntentType: String, Codable, CaseIterable {
    // MVP
    case calendarEvent
    case reminder
    case note
    case contactReference

    // Planned
    case call
    case message
    case location
    case meeting
    case shopping
    case followUp
    case idea
}
