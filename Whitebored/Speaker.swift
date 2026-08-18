import AVFoundation
import Foundation

enum SpeakerError: LocalizedError {
    case missingKey
    case http(Int, String)
    case empty
    case playFailed

    var errorDescription: String? {
        switch self {
        case .missingKey: return "missing openai key for voice"
        case .http(let code, let body): return "voice error \(code): \(body)"
        case .empty: return "voice returned nothing"
        case .playFailed: return "could not play voice"
        }
    }
}

@MainActor
final class Speaker: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var waiting: CheckedContinuation<Void, Error>?
    private var progressTask: Task<Void, Never>?
    private var clipProgress: ((Double) -> Void)?
    private var prefetch: Task<Data, Error>?
    private var generation = 0
    var rate: Float = 1 {
        didSet {
            player?.enableRate = true
            player?.rate = rate
        }
    }

    func say(_ text: String, voice: String, onProgress: ((Double) -> Void)? = nil) async throws {
        let parts = Self.sentences(from: text)
        guard !parts.isEmpty else { return }
        stop()
        let gen = generation
        let weights = parts.map { max($0.split { $0.isWhitespace || $0.isNewline }.count, 1) }
        let total = Double(weights.reduce(0, +))
        var next = try await fetch(parts[0], voice: voice)
        guard gen == generation else { return }
        var before = 0
        for (i, _) in parts.enumerated() {
            guard gen == generation else { return }
            let data = next
            let upcoming: Task<Data, Error>? = i + 1 < parts.count
                ? Task { try await self.fetch(parts[i + 1], voice: voice) }
                : nil
            prefetch = upcoming
            let weight = weights[i]
            let start = before
            try await play(data) { local in
                onProgress?((Double(start) + local * Double(weight)) / total)
            }
            before += weight
            guard gen == generation else { return }
            if let upcoming {
                next = try await upcoming.value
            }
        }
    }

    func stop() {
        generation += 1
        prefetch?.cancel()
        prefetch = nil
        progressTask?.cancel()
        progressTask = nil
        player?.stop()
        player = nil
        finish(error: nil)
    }

    private static func sentences(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var parts: [String] = []
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { substring, _, _, _ in
            guard let piece = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !piece.isEmpty else { return }
            parts.append(piece)
        }
        return parts.isEmpty ? [trimmed] : parts
    }

    private func fetch(_ text: String, voice: String) async throws -> Data {
        guard let key = Config.openaiKey else { throw SpeakerError.missingKey }
        let payload: [String: Any] = [
            "model": Config.ttsModel,
            "voice": voice,
            "input": text,
            "response_format": "mp3",
            "instructions": "Warm, clear tutor sitting across a table. Unhurried. Human. Like a smart friend explaining an idea, not a narrator and not a customer-service bot."
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = obj["error"] as? [String: Any],
               let message = err["message"] as? String {
                throw SpeakerError.http(status, message)
            }
            throw SpeakerError.http(status, String(snippet.prefix(240)))
        }
        if data.isEmpty { throw SpeakerError.empty }
        return data
    }

    private func play(_ data: Data, onProgress: @escaping (Double) -> Void) async throws {
        clipProgress = onProgress
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("whitebored-voice-\(UUID().uuidString).mp3")
        try data.write(to: url, options: .atomic)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            waiting = cont
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.enableRate = true
                player.rate = rate
                player.volume = 1
                player.prepareToPlay()
                self.player = player
                if !player.play() {
                    finish(error: SpeakerError.playFailed)
                } else {
                    self.tickProgress()
                }
            } catch {
                finish(error: error)
            }
        }
    }

    private func tickProgress() {
        progressTask?.cancel()
        progressTask = Task { @MainActor in
            while !Task.isCancelled {
                guard let player = self.player, player.isPlaying else { break }
                let duration = player.duration
                if duration > 0 {
                    self.clipProgress?(min(1, player.currentTime / duration))
                }
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.finish(error: flag ? nil : SpeakerError.playFailed)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in self.finish(error: error ?? SpeakerError.playFailed) }
    }

    private func finish(error: Error?) {
        progressTask?.cancel()
        progressTask = nil
        clipProgress = nil
        guard let waiting else { return }
        self.waiting = nil
        if let error {
            waiting.resume(throwing: error)
        } else {
            waiting.resume()
        }
    }
}
