import AVFoundation
import Foundation

enum SpeakerError: LocalizedError {
    case missingKey
    case http(Int, String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey: return "missing openai key for voice"
        case .http(let code, let body): return "voice error \(code): \(body)"
        case .empty: return "voice returned nothing"
        }
    }
}

@MainActor
final class Speaker: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var waiting: CheckedContinuation<Void, Never>?

    func say(_ text: String) async throws {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        stop()
        let data = try await fetch(cleaned)
        try await play(data)
    }

    func stop() {
        player?.stop()
        player = nil
        finish()
    }

    private func fetch(_ text: String) async throws -> Data {
        guard let key = Config.openaiKey else { throw SpeakerError.missingKey }
        let payload: [String: Any] = [
            "model": Config.ttsModel,
            "voice": Config.ttsVoice,
            "input": text,
            "response_format": "wav",
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

    private func play(_ data: Data) async throws {
        await withCheckedContinuation { cont in
            waiting = cont
            do {
                let player = try AVAudioPlayer(data: data)
                player.delegate = self
                player.prepareToPlay()
                self.player = player
                if !player.play() {
                    finish()
                }
            } catch {
                finish()
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in self.finish() }
    }

    private func finish() {
        guard let waiting else { return }
        self.waiting = nil
        waiting.resume()
    }
}
