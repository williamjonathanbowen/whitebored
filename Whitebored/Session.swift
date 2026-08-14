import AppKit
import Foundation
import Observation

enum Phase {
    case key
    case goal
    case session
}

enum RunStatus: Equatable {
    case silent
    case thinking
    case speaking
    case blocked(String)
}

@Observable
@MainActor
final class Session {
    var phase: Phase
    var goal = ""
    var keyDraft = ""
    var voiceKeyDraft = ""
    var status: RunStatus = .silent
    var svg = ""
    var spoken = ""
    var heard = ""
    var liveHeard = ""
    var flash = false
    var criteria: [String] = []

    let camera = CameraService()
    let speech = SpeechListener()
    let speaker = Speaker()
    let hotkey = HotkeyMonitor()

    private var history: [ChatMessage] = []
    private var busy = false

    init() {
        Config.bootstrap()
        phase = Config.needsKeys ? .key : .goal
        speech.onLive = { [weak self] text in
            self?.liveHeard = text
        }
        hotkey.handler = { [weak self] in
            Task { await self?.capture() }
        }
    }

    func saveKeys() {
        if !keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Config.saveAnthropic(keyDraft)
        }
        if !voiceKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Config.saveOpenAI(voiceKeyDraft)
        }
        if !Config.needsKeys {
            phase = .goal
        }
    }

    func start() async {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        goal = trimmed
        phase = .session
        status = .silent
        hotkey.start()
        await camera.start()
        await speech.start()
    }

    func capture() async {
        guard phase == .session else { return }
        await turn()
    }

    private func turn() async {
        guard !busy else { return }
        busy = true
        speaker.stop()
        status = .thinking
        flash = true
        Task {
            try? await Task.sleep(nanoseconds: 140_000_000)
            self.flash = false
        }

        let photo = await camera.jpeg()
        let jpeg = photo.map { TutorClient.jpegFitting($0) }
        let said = speech.consume()
        heard = said
        liveHeard = ""

        let criteriaBlock = criteria.isEmpty
            ? "(none yet)"
            : criteria.map { "- \($0)" }.joined(separator: "\n")
        let first = history.isEmpty
        let userText = """
        North star: \(goal)

        Success criteria so far:
        \(criteriaBlock)

        \(first ? "This is the first time they asked you to talk. Give a clear, useful start on the idea. Do not assign a worksheet." : "They pressed Option-Command. Give a clear answer.")

        Speech since last turn:
        \(said.isEmpty ? "(silence)" : said)

        Look at the photo if there is one. Help them understand. Speak a clear answer they can also read on screen.
        """

        var blocks: [ContentBlock] = []
        if let jpeg {
            blocks.append(.jpeg(jpeg))
        }
        blocks.append(.text(userText))
        let liveMessage = ChatMessage(role: "user", blocks: blocks)

        do {
            let reply = try await TutorClient.complete(messages: history + [liveMessage])
            history.append(
                ChatMessage(
                    role: "user",
                    blocks: [.text(userText + (jpeg == nil ? "\n\n(no photo this turn)" : "\n\n(a photo was shown)"))]
                )
            )
            history.append(
                ChatMessage(
                    role: "assistant",
                    blocks: [.text(reply.speak + "\n\n(You updated the whiteboard.)")]
                )
            )
            if history.count > 24 {
                history = Array(history.suffix(24))
            }
            svg = reply.svg
            spoken = reply.speak
            if !reply.criteria.isEmpty {
                criteria = reply.criteria
            }
            status = .speaking
            try await speaker.say(reply.speak)
            status = .silent
        } catch {
            status = .blocked(error.localizedDescription)
        }
        busy = false
    }
}
