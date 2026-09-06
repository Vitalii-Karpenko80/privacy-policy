import Foundation
import AVFoundation
import Speech
import EventKit
import Contacts

/// Requests OS permissions lazily — only when a feature first needs them (ТЗ §20).
///
/// Each method is safe to call repeatedly; the system only prompts once.
struct PermissionService {

    // MARK: Microphone

    @discardableResult
    func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: Speech recognition

    @discardableResult
    func requestSpeech() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Convenience: both permissions needed to record and transcribe.
    func requestListening() async -> Bool {
        async let mic = requestMicrophone()
        async let speech = requestSpeech()
        return await mic && speech
    }

    // MARK: Calendar

    @discardableResult
    func requestCalendar(store: EKEventStore) async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    // MARK: Reminders

    @discardableResult
    func requestReminders(store: EKEventStore) async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    // MARK: Contacts

    @discardableResult
    func requestContacts(store: CNContactStore) async -> Bool {
        (try? await store.requestAccess(for: .contacts)) ?? false
    }
}
