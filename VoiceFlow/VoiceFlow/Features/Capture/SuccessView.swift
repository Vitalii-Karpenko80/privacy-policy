import SwiftUI

/// "Готово" — confirms what was created and where.
struct SuccessView: View {
    let summary: [String]
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                ZStack {
                    Circle().fill(Theme.Palette.taskSoft).frame(width: 112, height: 112)
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: 0x16B67F), Color(hex: 0x0E9C6B)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 84, height: 84)
                        .overlay(Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold)).foregroundStyle(.white))
                        .shadow(color: Theme.Palette.task.opacity(0.34), radius: 13, y: 12)
                }
                Text("Готово").font(.system(size: 27, weight: .bold)).padding(.top, 22)
                Text("Всё разложено по местам")
                    .font(.system(size: 15)).foregroundStyle(Theme.Palette.inkSecondary)
                    .padding(.top, 6)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(summary.enumerated()), id: \.offset) { index, line in
                            if index > 0 { Divider().padding(.leading, 16) }
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.Palette.task)
                                Text(line).font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .padding(14)
                        }
                    }
                    .card(padding: 0)
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, 28)

                Spacer()
                Button("На главный", action: onClose)
                    .buttonStyle(PrimaryButtonStyle(fill: Theme.Palette.ink))
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, 30)
            }
        }
    }
}
