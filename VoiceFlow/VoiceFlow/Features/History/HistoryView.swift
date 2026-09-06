import SwiftUI
import SwiftData

/// History of processed commands. Natural-language search is a post-MVP goal (ТЗ §16);
/// for now the search field filters transcripts.
struct HistoryView: View {
    @Query(sort: \CommandRecord.createdAt, order: .reverse)
    private var records: [CommandRecord]
    @State private var search = ""

    private var filtered: [CommandRecord] {
        guard !search.isEmpty else { return records }
        return records.filter { $0.transcript.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()
                if records.isEmpty {
                    ContentUnavailableView("Пока пусто", systemImage: "clock",
                                           description: Text("Здесь появятся ваши голосовые команды."))
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filtered) { record in
                                HistoryCard(record: record)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screen)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("История")
            .searchable(text: $search, prompt: "Что я обсуждал…")
            .navigationDestination(for: String.self) { name in
                ContactContextView(contactName: name)
            }
        }
    }
}

private struct HistoryCard: View {
    let record: CommandRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("«\(record.transcript)»").font(.system(size: 15)).lineLimit(2)
                Spacer(minLength: 8)
                Text(record.createdAt, style: .time)
                    .font(.system(size: 12.5)).foregroundStyle(Theme.Palette.inkFaint)
            }
            HStack(spacing: 8) {
                if record.eventsCount > 0 { Tag(text: "📅 \(record.eventsCount) событие", color: Theme.Palette.event, soft: Theme.Palette.eventSoft) }
                if record.tasksCount > 0 { Tag(text: "✓ \(record.tasksCount) задача", color: Theme.Palette.task, soft: Theme.Palette.taskSoft) }
                if record.notesCount > 0 { Tag(text: "📝 \(record.notesCount) заметка", color: Theme.Palette.note, soft: Theme.Palette.noteSoft) }
                ForEach(record.contactNames, id: \.self) { name in
                    NavigationLink(value: name) {
                        Tag(text: "👤 \(name)", color: Theme.Palette.contact, soft: Theme.Palette.contactSoft)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }
}

struct Tag: View {
    let text: String
    let color: Color
    let soft: Color
    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(soft, in: RoundedRectangle(cornerRadius: 8))
    }
}
