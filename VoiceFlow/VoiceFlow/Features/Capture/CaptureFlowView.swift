import SwiftUI

/// Full-screen capture flow: Listening → Processing → Review → Done.
struct CaptureFlowView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var coordinator: CaptureCoordinator?

    var body: some View {
        ZStack {
            if let coordinator {
                switch coordinator.phase {
                case .idle, .listening:
                    RecordingView(
                        coordinator: coordinator,
                        onCancel: { dismiss() },
                        onStop: { Task { await coordinator.stopAndParse() } }
                    )
                case .processing:
                    ProcessingView(transcript: coordinator.transcript)
                case .review:
                    ReviewView(
                        coordinator: coordinator,
                        onCancel: { dismiss() },
                        onAddAll: { Task { await coordinator.addAll(context: modelContext) } }
                    )
                case .done:
                    SuccessView(summary: coordinator.executionSummary) { dismiss() }
                case .failed(let message):
                    CaptureErrorView(
                        message: message,
                        onRetry: { Task { await coordinator.startListening() } },
                        onClose: { dismiss() }
                    )
                }
            } else {
                Color(Theme.Palette.listeningBackground).ignoresSafeArea()
            }
        }
        .task {
            guard coordinator == nil else { return }
            let created = CaptureCoordinator(services: services)
            coordinator = created
            await created.startListening()
        }
    }
}

// MARK: - Recording (dark "listening" screen)

struct RecordingView: View {
    @Bindable var coordinator: CaptureCoordinator
    var onCancel: () -> Void
    var onStop: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.listeningBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    Spacer()
                    listeningPill
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView {
                    Text(coordinator.transcript.isEmpty ? "Говорите…" : coordinator.transcript)
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(coordinator.transcript.isEmpty ? .white.opacity(0.35) : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 26)
                        .padding(.top, 30)
                }

                Spacer()
                WaveformView()
                    .frame(height: 64)
                    .padding(.bottom, 8)

                Button(action: onStop) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.08)).frame(width: 74, height: 74)
                        RoundedRectangle(cornerRadius: 7).fill(Color(hex: 0xFF5C5C)).frame(width: 26, height: 26)
                    }
                }
                .padding(.top, 20)
                Text("Коснитесь, чтобы завершить")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 12)
                    .padding(.bottom, 36)
            }
        }
    }

    private var listeningPill: some View {
        HStack(spacing: 9) {
            Circle().fill(Color(hex: 0xFF5C5C)).frame(width: 9, height: 9)
            Text("Слушаю…").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}

/// Animated waveform driven by the display clock (no manual animation state).
struct WaveformView: View {
    private let barCount = 18
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: 0x9E98FF), Color(hex: 0x6B63F0)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 5, height: barHeight(index: i, time: t))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func barHeight(index: Int, time: Double) -> CGFloat {
        let wave = abs(sin(time * 3 + Double(index) * 0.55))
        return 12 + wave * 40
    }
}

// MARK: - Processing

struct ProcessingView: View {
    let transcript: String
    var body: some View {
        ZStack {
            Theme.Palette.listeningBackground.ignoresSafeArea()
            VStack(spacing: 22) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color(hex: 0x9E98FF))
                Text("Раскладываю по местам…")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(transcript)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineLimit(3)
            }
        }
    }
}

// MARK: - Error

struct CaptureErrorView: View {
    let message: String
    var onRetry: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Palette.note)
                Text(message)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.ink)
                    .padding(.horizontal, 40)
                Button("Попробовать снова", action: onRetry)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                Button("Закрыть", action: onClose)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }
}
