import SwiftUI
import SwiftData
import EventKit

/// Main screen: today's timeline + the big mic button.
struct HomeView: View {
    @Environment(AppServices.self) private var services
    var onStartCapture: () -> Void

    @State private var todaysEvents: [EKEvent] = []
    @Query(sort: \CommandRecord.createdAt, order: .reverse)
    private var history: [CommandRecord]

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        todaySection
                        if let last = history.first { recentCommand(last) }
                    }
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.top, 8)
                }
                micDock
            }
        }
        .task { await loadToday() }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("VOICEFLOW")
                    .font(.system(size: 12, weight: .bold)).tracking(1.6)
                    .foregroundStyle(Theme.Palette.accent)
                Text(Self.dateText).font(.system(size: 15)).foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer()
            Circle().fill(Theme.Palette.accentSoft).frame(width: 40, height: 40)
                .overlay(Image(systemName: "person.fill").foregroundStyle(Theme.Palette.accent))
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сегодня").font(.system(size: 26, weight: .bold))

            if todaysEvents.isEmpty {
                VStack(spacing: 6) {
                    Text("На сегодня пусто")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Нажмите микрофон и скажите, что нужно запомнить.")
                        .font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todaysEvents.enumerated()), id: \.offset) { index, event in
                        if index > 0 { Divider().padding(.leading, 74) }
                        TimelineRow(event: event)
                    }
                }
                .card(padding: 0)
            }
        }
    }

    private func recentCommand(_ record: CommandRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Недавняя команда")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.inkSecondary)
                .padding(.leading, 4)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("«\(record.transcript)»").font(.system(size: 14)).lineLimit(1)
                    Text(record.summaryLine).font(.system(size: 12.5)).foregroundStyle(Theme.Palette.inkSecondary)
                }
                Spacer()
                Text(record.createdAt, style: .time)
                    .font(.system(size: 12.5)).foregroundStyle(Theme.Palette.inkFaint)
            }
            .card()
        }
    }

    private var micDock: some View {
        VStack(spacing: 12) {
            Button(action: onStartCapture) {
                ZStack {
                    Circle().fill(Theme.Palette.accentSoft).frame(width: 132, height: 132)
                    Circle().fill(Color(hex: 0xDEDBFA)).frame(width: 114, height: 114)
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: 0x6B63F0), Color(hex: 0x938DFF)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 106, height: 106)
                        .overlay(Image(systemName: "mic.fill").font(.system(size: 40)).foregroundStyle(.white))
                        .shadow(color: Theme.Palette.accent.opacity(0.42), radius: 15, y: 14)
                }
            }
            .buttonStyle(.plain)
            Text("Что нужно запомнить?").font(.system(size: 19, weight: .semibold))
            Text("Нажмите и говорите").font(.system(size: 14)).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: Data

    private func loadToday() async {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        todaysEvents = services.calendar.events(on: .now)
    }

    private static var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: .now).capitalizedFirstLetter
    }
}

/// One row in the Home timeline.
private struct TimelineRow: View {
    let event: EKEvent
    var body: some View {
        HStack(spacing: 13) {
            Text(event.startDate, style: .time)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.inkSecondary)
                .frame(width: 48, alignment: .leading)
            IconChip(symbol: "calendar", tint: Theme.Palette.event, soft: Theme.Palette.eventSoft)
            Text(event.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

extension CommandRecord {
    var summaryLine: String {
        var parts: [String] = []
        if eventsCount > 0 { parts.append("📅 \(eventsCount)") }
        if tasksCount > 0 { parts.append("✓ \(tasksCount)") }
        if notesCount > 0 { parts.append("📝 \(notesCount)") }
        if let name = contactNames.first { parts.append("👤 \(name)") }
        return parts.joined(separator: " · ")
    }
}

extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
