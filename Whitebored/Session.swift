import AppKit
import Foundation
import Observation
import SwiftUI

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
    var cards: [String] = []
    var cardIndex = 0
    var heard = ""
    var liveHeard = ""
    var typedDraft = ""
    var muted = false
    var timerRemaining: TimeInterval = 15 * 60
    var timerRunning = false
    var flash = false
    var criteria: [String] = []
    var lessons: [LessonRecord] = []
    var showHistory = false
    var showSettings = false
    var showTimeline = false
    var askingWhoStarts = false
    var typeSize: Double
    var typeface: String
    var voice: String
    var voiceSpeed: Double
    var learnt = ""
    var observation = ""
    var talkCount = 0
    var typeCount = 0
    var photoCount = 0

    let camera = CameraService()
    let speech = SpeechListener()
    let speaker = Speaker()
    let hotkey = HotkeyMonitor()

    private var history: [ChatMessage] = []
    private var busy = false
    private var followSpeech = true
    private var timerTask: Task<Void, Never>?
    private(set) var currentLessonID: UUID?
    private var voiceTask: Task<Void, Error>?

    init() {
        Config.bootstrap()
        typeSize = UserDefaults.standard.object(forKey: "typeSize") as? Double ?? 18
        typeface = UserDefaults.standard.string(forKey: "typeface") ?? "serif"
        let savedVoice = UserDefaults.standard.string(forKey: "ttsVoice") ?? Config.ttsVoice
        voice = Config.ttsVoices.contains(savedVoice) ? savedVoice : Config.ttsVoice
        let savedSpeed = UserDefaults.standard.object(forKey: "ttsSpeed") as? Double ?? 1
        voiceSpeed = Config.ttsSpeeds.contains(savedSpeed) ? savedSpeed : 1
        phase = Config.needsKeys ? .key : .goal
        lessons = LessonStore.load()
        speaker.rate = Float(voiceSpeed)
        speech.onLive = { [weak self] text in
            self?.liveHeard = text
        }
        hotkey.handler = { [weak self] in
            Task { await self?.send() }
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

    func offerStart() {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        goal = trimmed
        askingWhoStarts = true
    }

    func chooseWhoStarts(whiteboredFirst: Bool) async {
        guard askingWhoStarts else { return }
        askingWhoStarts = false
        await start()
        if whiteboredFirst {
            await send()
        }
    }

    func start() async {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        askingWhoStarts = false
        persistCurrent()
        goal = trimmed
        let lesson = LessonRecord(
            id: UUID(),
            goal: trimmed,
            createdAt: Date(),
            updatedAt: Date(),
            svg: "",
            cards: [],
            cardIndex: 0,
            criteria: [],
            spoken: "",
            heard: "",
            messages: []
        )
        currentLessonID = lesson.id
        svg = ""
        spoken = ""
        cards = []
        cardIndex = 0
        heard = ""
        liveHeard = ""
        typedDraft = ""
        criteria = []
        history = []
        lessons.insert(lesson, at: 0)
        learnt = ""
        observation = ""
        talkCount = 0
        typeCount = 0
        photoCount = 0
        persistCurrent()
        phase = .session
        status = .silent
        showHistory = false
        showSettings = false
        showTimeline = false
        hotkey.start()
        await camera.start()
        await speech.start()
    }

    func send() async {
        guard phase == .session, !busy else { return }
        let typed = typedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        typedDraft = ""
        await turn(typed: typed)
    }

    func capture() async {
        await send()
    }

    func submitTyped() async {
        await send()
    }

    func prevCard() {
        followSpeech = false
        if cardIndex > 0 { cardIndex -= 1 }
    }

    func nextCard() {
        followSpeech = false
        if cardIndex + 1 < cards.count { cardIndex += 1 }
    }

    func goToCard(_ index: Int) {
        followSpeech = false
        guard cards.indices.contains(index) else { return }
        cardIndex = index
    }

    func toggleMute() {
        muted.toggle()
        speech.setUserMuted(muted)
    }

    func toggleHistory() {
        showHistory.toggle()
        if showHistory {
            showSettings = false
            showTimeline = false
        }
    }

    func toggleSettings() {
        showSettings.toggle()
        showTimeline = false
        if showSettings {
            showHistory = false
        }
    }

    func openTimeline() {
        showSettings = true
        showTimeline = true
        showHistory = false
    }

    func setTypeSize(_ size: Double) {
        typeSize = size
        UserDefaults.standard.set(size, forKey: "typeSize")
    }

    func setTypeface(_ name: String) {
        if name == "random" {
            typeface = ["system", "serif", "lato", "arial"].randomElement() ?? "serif"
        } else {
            typeface = name
        }
        UserDefaults.standard.set(typeface, forKey: "typeface")
    }

    func setVoice(_ name: String) {
        guard Config.ttsVoices.contains(name) else { return }
        voice = name
        UserDefaults.standard.set(name, forKey: "ttsVoice")
    }

    func setVoiceSpeed(_ speed: Double) {
        guard Config.ttsSpeeds.contains(speed) else { return }
        voiceSpeed = speed
        UserDefaults.standard.set(speed, forKey: "ttsSpeed")
        speaker.rate = Float(speed)
    }

    func uiFont(_ size: Double? = nil) -> Font {
        let s = size ?? typeSize
        switch typeface {
        case "lato":
            return .custom("Lato", size: s)
        case "arial":
            return .custom("Arial", size: s)
        case "system":
            return .system(size: s)
        default:
            return .system(size: s, design: .serif)
        }
    }

    func nsFont(_ size: Double? = nil) -> NSFont {
        let s = CGFloat(size ?? typeSize)
        switch typeface {
        case "lato":
            return NSFont(name: "Lato", size: s) ?? NSFont(name: "Lato-Regular", size: s) ?? .systemFont(ofSize: s)
        case "arial":
            return NSFont(name: "Arial", size: s) ?? .systemFont(ofSize: s)
        case "system":
            return .systemFont(ofSize: s)
        default:
            let base = NSFont.systemFont(ofSize: s)
            if let serif = base.fontDescriptor.withDesign(.serif) {
                return NSFont(descriptor: serif, size: s) ?? base
            }
            return base
        }
    }

    func beginNew() {
        persistCurrent()
        hotkey.stop()
        speaker.stop()
        voiceTask?.cancel()
        voiceTask = nil
        currentLessonID = nil
        goal = ""
        svg = ""
        spoken = ""
        cards = []
        cardIndex = 0
        heard = ""
        liveHeard = ""
        typedDraft = ""
        criteria = []
        learnt = ""
        observation = ""
        talkCount = 0
        typeCount = 0
        photoCount = 0
        history = []
        status = .silent
        askingWhoStarts = false
        phase = .goal
        showHistory = false
        showSettings = false
        showTimeline = false
    }

    func openLesson(_ id: UUID) async {
        persistCurrent()
        guard let lesson = lessons.first(where: { $0.id == id }) else { return }
        speaker.stop()
        voiceTask?.cancel()
        voiceTask = nil
        currentLessonID = lesson.id
        goal = lesson.goal
        svg = lesson.svg
        spoken = lesson.spoken
        cards = lesson.cards
        cardIndex = lesson.cardIndex
        heard = lesson.heard
        liveHeard = ""
        typedDraft = ""
        criteria = lesson.criteria
        learnt = lesson.learnt
        observation = lesson.observation
        talkCount = lesson.talkCount
        typeCount = lesson.typeCount
        photoCount = lesson.photoCount
        history = lesson.messages.map { ChatMessage(role: $0.role, blocks: [.text($0.text)]) }
        status = .silent
        askingWhoStarts = false
        phase = .session
        showHistory = false
        showSettings = false
        showTimeline = false
        hotkey.start()
        await camera.start()
        await speech.start()
    }

    var timerLabel: String {
        let seconds = max(0, Int(timerRemaining.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func togglePowerTimer() {
        if timerRunning {
            timerTask?.cancel()
            timerTask = nil
            timerRunning = false
            return
        }
        startPowerTimer()
    }

    func startPowerTimer() {
        guard !timerRunning else { return }
        timerTask?.cancel()
        let end = Date().addingTimeInterval(15 * 60)
        timerRemaining = 15 * 60
        timerRunning = true
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let left = end.timeIntervalSinceNow
                if left <= 0 {
                    self.timerRemaining = 0
                    self.timerRunning = false
                    return
                }
                self.timerRemaining = left
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func turn(typed: String) async {
        guard !busy else { return }
        busy = true
        speaker.stop()
        voiceTask?.cancel()
        voiceTask = nil
        status = .thinking
        flash = true
        Task {
            try? await Task.sleep(nanoseconds: 140_000_000)
            self.flash = false
        }

        let photo = await camera.jpeg()
        let jpeg = photo.map { TutorClient.jpegFitting($0) }
        let mic = speech.consume()
        if jpeg != nil { photoCount += 1 }
        if !typed.isEmpty { typeCount += 1 }
        if !mic.isEmpty { talkCount += 1 }
        let said = [typed, mic].filter { !$0.isEmpty }.joined(separator: "\n")
        heard = said
        liveHeard = ""
        speech.pause()

        let criteriaBlock = criteria.isEmpty
            ? "(none yet)"
            : criteria.map { "- \($0)" }.joined(separator: "\n")
        let first = history.isEmpty
        let how: String
        if !typed.isEmpty && !mic.isEmpty {
            how = "They typed a note and also spoke."
        } else if !typed.isEmpty {
            how = "They typed a note."
        } else {
            how = "They pressed Enter."
        }
        let userText = """
        North star: \(goal)

        Success criteria so far:
        \(criteriaBlock)

        \(first ? "This is the first time they asked you to talk. Give a clear, useful start on the idea. Do not assign a worksheet." : "\(how) Give a clear answer.")

        What they said or typed since last turn:
        \(said.isEmpty ? "(silence)" : said)

        Look at the photo if there is one. Help them understand. Speak a clear answer they can also read on flashcards.
        """

        var blocks: [ContentBlock] = []
        if let jpeg {
            blocks.append(.jpeg(jpeg))
        }
        blocks.append(.text(userText))
        let liveMessage = ChatMessage(role: "user", blocks: blocks)

        do {
            let reply = try await TutorClient.complete(messages: history + [liveMessage]) { [weak self] speak in
                await self?.beginSpeaking(speak)
            }
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
            if TutorClient.hasInk(reply.svg) {
                svg = reply.svg
            }
            let board = reply.board
            let spokenReply = reply.speak
            let drawTask: Task<String, Never>? = board.isEmpty ? nil : Task {
                (try? await TutorClient.draw(board: board, speak: spokenReply)) ?? ""
            }
            if voiceTask == nil {
                beginSpeaking(reply.speak)
            }
            if !reply.criteria.isEmpty {
                criteria = reply.criteria
            }
            if !reply.learnt.isEmpty {
                learnt = reply.learnt
            }
            if !reply.observe.isEmpty {
                observation = reply.observe
            }
            persistCurrent()
            if let drawTask {
                let drawn = await drawTask.value
                if TutorClient.hasInk(drawn) {
                    svg = drawn
                    persistCurrent()
                }
            }
            if let voiceTask {
                do {
                    try await voiceTask.value
                } catch is CancellationError {}
            }
            status = .silent
        } catch {
            status = .blocked(error.localizedDescription)
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        speech.resume()
        busy = false
    }

    private static func cards(from speak: String) -> [String] {
        let trimmed = speak.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var parts: [String] = []
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { substring, _, _, _ in
            guard let piece = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !piece.isEmpty else { return }
            parts.append(piece)
        }
        return parts.isEmpty ? [trimmed] : parts
    }

    private func followCards(_ progress: Double) {
        guard followSpeech, !cards.isEmpty else { return }
        cardIndex = Self.cardIndex(progress: progress, cards: cards)
    }

    private static func cardIndex(progress: Double, cards: [String]) -> Int {
        let weights = cards.map { max($0.split { $0.isWhitespace || $0.isNewline }.count, 1) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        let target = min(1, max(0, progress)) * Double(total)
        var acc = 0.0
        for (i, weight) in weights.enumerated() {
            acc += Double(weight)
            if target <= acc || i == cards.count - 1 {
                return i
            }
        }
        return cards.count - 1
    }

    private func beginSpeaking(_ speak: String) {
        spoken = speak
        cards = Self.cards(from: speak)
        cardIndex = 0
        followSpeech = true
        status = .speaking
        voiceTask = Task { [weak self] in
            guard let self else { return }
            try await self.speaker.say(speak, voice: self.voice) { [weak self] progress in
                self?.followCards(progress)
            }
        }
    }

    private func persistCurrent() {
        guard let currentLessonID else { return }
        let record = LessonRecord(
            id: currentLessonID,
            goal: goal,
            createdAt: lessons.first(where: { $0.id == currentLessonID })?.createdAt ?? Date(),
            updatedAt: Date(),
            svg: svg,
            cards: cards,
            cardIndex: cardIndex,
            criteria: criteria,
            spoken: spoken,
            heard: heard,
            messages: history.compactMap { message in
                let text = message.blocks.compactMap { block -> String? in
                    if case .text(let text) = block { return text }
                    return nil
                }.joined(separator: "\n")
                guard !text.isEmpty else { return nil }
                return StoredMessage(role: message.role, text: text)
            },
            learnt: learnt,
            observation: observation,
            talkCount: talkCount,
            typeCount: typeCount,
            photoCount: photoCount
        )
        if let index = lessons.firstIndex(where: { $0.id == currentLessonID }) {
            lessons[index] = record
        } else {
            lessons.insert(record, at: 0)
        }
        lessons.sort { $0.updatedAt > $1.updatedAt }
        LessonStore.save(lessons)
    }
}
