import Foundation
import Speech
import AVFoundation

enum SpeechServiceError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioSession(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Нет доступа к микрофону или распознаванию речи."
        case .recognizerUnavailable: return "Распознавание речи недоступно для выбранного языка."
        case .audioSession(let error): return error.localizedDescription
        }
    }
}

/// Live speech-to-text using `SFSpeechRecognizer` + `AVAudioEngine`.
///
/// Streams partial transcripts through `onTranscript` while recording, and
/// returns the final text from `stop()`.
final class SpeechService {
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private(set) var latestTranscript = ""

    init(locale: Locale = Locale(identifier: "ru_RU")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Begins recording. `onTranscript` fires on the main actor with the running text.
    func start(onTranscript: @escaping (String) -> Void) throws {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted else {
            throw SpeechServiceError.notAuthorized
        }
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechServiceError.recognizerUnavailable
        }

        // Reset any previous run.
        reset()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechServiceError.audioSession(error)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            self.latestTranscript = text
            DispatchQueue.main.async { onTranscript(text) }
        }
    }

    /// Stops recording and returns the final transcript.
    @discardableResult
    func stop() -> String {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        request?.endAudio()
        task?.finish()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return latestTranscript
    }

    private func reset() {
        task?.cancel()
        task = nil
        request = nil
        latestTranscript = ""
    }
}
