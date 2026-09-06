import SwiftUI
import SwiftData
import EventKit

/// Personal-CRM view: aggregates everything VoiceFlow knows about a person —
/// next meeting, related notes (ТЗ §11). A lightweight "second brain".
struct ContactContextView: View {
    let contactName: String

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext

    @State private var match: ContactMatch?
    @State private var nextEvent: EKEvent?
    @State private var relatedNotes: [VoiceNote] = []

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    profile
                    if let nextEvent { nextMeetingCard(nextEvent) }
                    if !relatedNotes.isEmpty { notesSection }
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Контакт")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var profile: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xB06AE6), Color(hex: 0x8A3FD1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 76, height: 76)
                .overlay(Text(match?.initials ?? String(contactName.prefix(1)))
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(.white))
            Text(match?.displayName ?? contactName).font(.system(size: 22, weight: .bold))
            if let phone = match?.phoneNumber {
                Text(phone).font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
            } else {
                Text("Нет в контактах").font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
        .padding(.top, 8)
    }

    private func nextMeetingCard(_ event: EKEvent) -> some View {
        HStack(spacing: 12) {
            IconChip(symbol: "calendar", tint: Theme.Palette.event, soft: Theme.Palette.eventSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text("Следующая встреча").font(.system(size: 13)).foregroundStyle(Theme.Palette.inkSecondary)
                Text(event.title).font(.system(size: 16, weight: .semibold))
            }
            Spacer()
            Text(event.startDate, format: .dateTime.day().month().hour().minute())
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.Palette.event)
        }
        .card()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ЗАМЕТКИ").font(.system(size: 12, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.Palette.inkSecondary).padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(Array(relatedNotes.enumerated()), id: \.element.id) { index, note in
                    if index > 0 { Divider() }
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "note.text").foregroundStyle(Theme.Palette.note)
                        Text(note.text).font(.system(size: 15)).foregroundStyle(Theme.Palette.ink)
                        Spacer()
                    }
                    .padding(14)
                }
            }
            .card(padding: 0)
        }
    }

    // MARK: Data

    private func load() async {
        if await services.permissions.requestContacts(store: services.contactStore) {
            match = services.contacts.candidates(for: contactName).first
        }
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            nextEvent = upcomingEvent(matching: contactName)
        }
        relatedNotes = fetchNotes(for: match?.id)
    }

    private func upcomingEvent(matching name: String) -> EKEvent? {
        let store = services.eventStore
        let start = Date.now
        guard let end = Calendar.current.date(byAdding: .day, value: 60, to: start) else { return nil }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { $0.title.localizedCaseInsensitiveContains(name) }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    private func fetchNotes(for contactID: String?) -> [VoiceNote] {
        guard let contactID else { return [] }
        let descriptor = FetchDescriptor<VoiceNote>(
            predicate: #Predicate { $0.relatedContactID == contactID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
