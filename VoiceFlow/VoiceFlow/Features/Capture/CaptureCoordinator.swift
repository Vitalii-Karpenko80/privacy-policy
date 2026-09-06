import Foundation
import SwiftUI
import SwiftData
import Observation

/// Drives the core loop: Voice → Speech-to-Text → AIService → Review → Execute.
@Observable
@MainActor
final class CaptureCoordinator {
    enum Phase: Equatable {
        case idle
        case listening
        case processing
        case review
        case done
        case failed(String)
    }

    private let services: AppServices

    var phase: Phase = .idle
    var transcript = ""

    // Review state
    var events: [EventReviewItem] = []
    var tasks: [TaskReviewItem] = []
    var contacts: [ContactReviewItem] = []
    var notes: [NoteReviewItem] = []

    /// Human-readable summary of what was created, for the Success screen.
    var executionSummary: [String] = []

    init(services: AppServices) {
        self.services = services
    }

    var hasAnythingToReview: Bool {
        !events.isEmpty || !tasks.isEmpty || !contacts.isEmpty || !notes.isEmpty
    }

    // MARK: Recording

    func startListening() async {
        transcript = ""
        guard await services.permissions.requestListening() else {
            phase = .failed("Нужен доступ к микрофону и распознаванию речи.")
            return
        }
        do {
            phase = .listening
            try services.speech.start { [weak self] text in
                Task { @MainActor in self?.transcript = text }
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Stops recording and runs the AI parse.
    func stopAndParse() async {
        let finalText = services.speech.stop()
        transcript = finalText.isEmpty ? transcript : finalText
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("Ничего не распознано. Попробуйте ещё раз.")
            return
        }

        phase = .processing
        do {
            let candidates = await contactCandidateNames(in: transcript)
            let intent = try await services.makeAIService()
                .parse(command: transcript, contactCandidates: candidates, now: .now)
            buildReview(from: intent)
            phase = hasAnythingToReview ? .review : .failed("AI не нашёл действий в команде.")
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Pull a few likely first names out of the transcript and resolve to contacts,
    /// so only *candidate names* — not the whole address book — reach the AI.
    private func contactCandidateNames(in text: String) async -> [String] {
        guard await services.permissions.requestContacts(store: services.contactStore) else { return [] }
        // Heuristic: capitalised words are candidate names.
        let words = text.split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.first?.isUppercase == true && $0.count > 2 }
        var names: [String] = []
        for word in words {
            for match in services.contacts.candidates(for: word) where !names.contains(match.displayName) {
                names.append(match.displayName)
            }
        }
        return names
    }

    private func buildReview(from intent: ParsedIntent) {
        events = intent.events.map { EventReviewItem(event: $0) }
        tasks = intent.tasks.map { TaskReviewItem(task: $0) }
        notes = intent.notes.map { NoteReviewItem(note: $0) }
        contacts = intent.contacts.map { parsed in
            let candidates = services.contacts.candidates(for: parsed.name)
            return ContactReviewItem(parsed: parsed,
                                     candidates: candidates,
                                     selected: candidates.first)
        }
    }

    // MARK: Execute ("Add All")

    func addAll(context: ModelContext) async {
        var summary: [String] = []
        do {
            let needsCalendar = events.contains(where: \.include)
            let needsReminders = tasks.contains(where: \.include)
            if needsCalendar {
                guard await services.permissions.requestCalendar(store: services.eventStore) else {
                    throw SimpleError("Нет доступа к Календарю.")
                }
            }
            if needsReminders {
                guard await services.permissions.requestReminders(store: services.eventStore) else {
                    throw SimpleError("Нет доступа к Напоминаниям.")
                }
            }

            var firstEventStart: Date?
            var firstEventID: String?
            for item in events where item.include {
                let id = try services.calendar.createEvent(from: item.event)
                if firstEventStart == nil {
                    firstEventStart = DateResolver.date(dateString: item.event.date, timeString: item.event.time)
                    firstEventID = id
                }
                summary.append("Событие: \(item.event.title)")
                if item.event.reminderMinutes != nil { summary.append("Напоминание к событию") }
            }

            for item in tasks where item.include {
                try services.reminders.createReminder(from: item.task, relatedEventStart: firstEventStart)
                summary.append("Задача: \(item.task.title)")
            }

            let contactID = contacts.first(where: { $0.include })?.selected?.id
            for item in notes where item.include {
                context.insert(VoiceNote(text: item.note.text,
                                         relatedContactID: contactID,
                                         relatedEventID: firstEventID))
                summary.append("Заметка сохранена")
            }
            for item in contacts where item.include {
                summary.append("Контакт: \(item.selected?.displayName ?? item.parsed.name)")
            }

            context.insert(CommandRecord(transcript: transcript, intent: includedIntent))
            try context.save()

            executionSummary = summary
            phase = .done
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// The intent reduced to items the user kept — used for the history record.
    private var includedIntent: ParsedIntent {
        ParsedIntent(
            events: events.filter(\.include).map(\.event),
            tasks: tasks.filter(\.include).map(\.task),
            contacts: contacts.filter(\.include).map { ParsedContact(name: $0.selected?.displayName ?? $0.parsed.name) },
            notes: notes.filter(\.include).map(\.note)
        )
    }
}

private struct SimpleError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
