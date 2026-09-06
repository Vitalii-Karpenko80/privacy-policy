import Foundation
import EventKit
import Contacts
import Observation

/// Dependency container shared through the SwiftUI environment.
///
/// Holds the single EventKit / Contacts stores and the stateless services built
/// on top of them, plus user settings and the permission helper.
@Observable
final class AppServices {
    let settings: AppSettings
    let permissions = PermissionService()

    let eventStore = EKEventStore()
    let contactStore = CNContactStore()

    let speech = SpeechService()

    var calendar: CalendarService { CalendarService(store: eventStore) }
    var reminders: ReminderService { ReminderService(store: eventStore) }
    var contacts: ContactsService { ContactsService(store: contactStore) }

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func makeAIService() -> AIService { settings.makeAIService() }
}
