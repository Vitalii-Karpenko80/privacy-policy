import SwiftUI

/// "Я понял так" — the confirmation screen. Nothing is created until "Добавить всё".
struct ReviewView: View {
    @Bindable var coordinator: CaptureCoordinator
    var onCancel: () -> Void
    var onAddAll: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("«\(coordinator.transcript)»")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Palette.inkSecondary)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)

                        ForEach($coordinator.events) { $item in
                            EventCard(item: $item)
                        }
                        ForEach($coordinator.tasks) { $item in
                            TaskCard(item: $item)
                        }
                        ForEach($coordinator.contacts) { $item in
                            ContactCard(item: $item)
                        }
                        ForEach($coordinator.notes) { $item in
                            NoteCard(item: $item)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.vertical, 12)
                }

                Button("Добавить всё", action: onAddAll)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, 30)
                    .padding(.top, 8)
                    .background(Theme.Palette.background)
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
            }
            Spacer()
            Text("Я понял так").font(.system(size: 17, weight: .semibold))
            Spacer()
            Button(action: onCancel) {
                Text("Заново").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

// MARK: - Cards

private struct IncludeToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(isOn ? Theme.Palette.accent : Theme.Palette.inkFaint)
        }
        .buttonStyle(.plain)
    }
}

private struct CardHeader: View {
    let kind: String
    let title: String
    let tint: Color
    let soft: Color
    let symbol: String
    @Binding var include: Bool

    var body: some View {
        HStack(spacing: 12) {
            IconChip(symbol: symbol, tint: tint, soft: soft, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(1.2)
                    .foregroundStyle(tint)
                Text(title).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
            }
            Spacer(minLength: 8)
            IncludeToggle(isOn: $include)
        }
    }
}

private struct EventCard: View {
    @Binding var item: EventReviewItem
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(kind: "Событие", title: item.event.title,
                       tint: Theme.Palette.event, soft: Theme.Palette.eventSoft,
                       symbol: "calendar", include: $item.include)
            HStack(spacing: 16) {
                if let when = whenText {
                    Label(when, systemImage: "clock")
                }
                if let m = item.event.reminderMinutes {
                    Label("За \(m) мин", systemImage: "bell")
                }
            }
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.Palette.inkSecondary)

            if let notes = item.event.notes, !notes.isEmpty {
                Text("📝 \(notes)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xF6F5F2), in: RoundedRectangle(cornerRadius: 11))
            }
        }
        .card()
        .opacity(item.include ? 1 : 0.5)
    }

    private var whenText: String? {
        let parts = [item.event.date, item.event.time].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct TaskCard: View {
    @Binding var item: TaskReviewItem
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(kind: "Задача", title: item.task.title,
                       tint: Theme.Palette.task, soft: Theme.Palette.taskSoft,
                       symbol: "checkmark.circle", include: $item.include)
            if let due = dueText {
                Text(due).font(.system(size: 13.5)).foregroundStyle(Theme.Palette.inkSecondary)
                    .padding(.leading, 48)
            }
        }
        .card()
        .opacity(item.include ? 1 : 0.5)
    }

    private var dueText: String? {
        switch item.task.dueRelation {
        case "before_event": return "Срок: до встречи"
        case "today": return "Срок: сегодня"
        case "tomorrow": return "Срок: завтра"
        default: return item.task.dueDate
        }
    }
}

private struct ContactCard: View {
    @Binding var item: ContactReviewItem
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.Palette.contactSoft).frame(width: 36, height: 36)
                .overlay(Text(item.selected?.initials ?? "?")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Palette.contact))
            VStack(alignment: .leading, spacing: 2) {
                Text("КОНТАКТ").font(.system(size: 11, weight: .bold)).tracking(1.2)
                    .foregroundStyle(Theme.Palette.contact)
                Text(item.selected?.displayName ?? item.parsed.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(item.isFound ? "✓ Найден в контактах" : "Нет в контактах")
                    .font(.system(size: 13.5))
                    .foregroundStyle(item.isFound ? Theme.Palette.task : Theme.Palette.inkSecondary)
            }
            Spacer(minLength: 8)
            IncludeToggle(isOn: $item.include)
        }
        .card()
        .opacity(item.include ? 1 : 0.5)
    }
}

private struct NoteCard: View {
    @Binding var item: NoteReviewItem
    var body: some View {
        HStack(spacing: 12) {
            IconChip(symbol: "note.text", tint: Theme.Palette.note, soft: Theme.Palette.noteSoft, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("ЗАМЕТКА").font(.system(size: 11, weight: .bold)).tracking(1.2)
                    .foregroundStyle(Theme.Palette.note)
                Text(item.note.text).font(.system(size: 15)).foregroundStyle(Theme.Palette.ink)
            }
            Spacer(minLength: 8)
            IncludeToggle(isOn: $item.include)
        }
        .card()
        .opacity(item.include ? 1 : 0.5)
    }
}
