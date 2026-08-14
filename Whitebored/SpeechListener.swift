import AVFoundation
import Speech

@MainActor
final class SpeechListener {
    var onLive: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
        ?? SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var committed = ""
    private var live = ""
    private var generation = 0
    private var hasTap = false
    private var allowed = false

    var isAllowed: Bool { allowed }

    func start() async {
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        allowed = mic && speech == .authorized && (recognizer?.isAvailable ?? false)
        guard allowed else { return }
        begin()
    }

    func consume() -> String {
        let text = (committed + " " + live)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        committed = ""
        live = ""
        onLive?("")
        return text
    }

    func stop() {
        generation += 1
        teardown()
    }

    private func begin() {
        generation += 1
        let gen = generation
        teardown()
        guard let recognizer else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        hasTap = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, gen == self.generation else { return }
                if let result {
                    self.live = result.bestTranscription.formattedString
                    self.onLive?(self.live)
                    if result.isFinal {
                        self.rollForward()
                    }
                } else if error != nil {
                    self.rollForward()
                }
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard gen == self.generation else { return }
            self.rollForward()
        }
    }

    private func rollForward() {
        let piece = live.trimmingCharacters(in: .whitespacesAndNewlines)
        if !piece.isEmpty {
            committed = (committed + " " + piece)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        live = ""
        begin()
    }

    private func teardown() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if engine.isRunning { engine.stop() }
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
    }
}
