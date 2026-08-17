import Foundation

struct LessonRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var goal: String
    var createdAt: Date
    var updatedAt: Date
    var svg: String
    var cards: [String]
    var cardIndex: Int
    var criteria: [String]
    var spoken: String
    var heard: String
    var messages: [StoredMessage]
    var learnt: String
    var observation: String
    var talkCount: Int
    var typeCount: Int
    var photoCount: Int

    var styleLine: String {
        var bits: [String] = []
        if talkCount > typeCount && talkCount > 0 {
            bits.append("talked a lot")
        } else if typeCount > talkCount && typeCount > 0 {
            bits.append("wrote a lot")
        } else if talkCount > 0 && typeCount > 0 {
            bits.append("talked and wrote")
        } else if talkCount > 0 {
            bits.append("talked")
        } else if typeCount > 0 {
            bits.append("wrote")
        }
        if photoCount == 1 {
            bits.append("1 photo")
        } else if photoCount > 1 {
            bits.append("\(photoCount) photos")
        }
        let minutes = max(1, Int(updatedAt.timeIntervalSince(createdAt) / 60))
        bits.append("\(minutes) min")
        return bits.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id, goal, createdAt, updatedAt, svg, cards, cardIndex, criteria, spoken, heard, messages
        case learnt, observation, talkCount, typeCount, photoCount
    }

    init(
        id: UUID,
        goal: String,
        createdAt: Date,
        updatedAt: Date,
        svg: String,
        cards: [String],
        cardIndex: Int,
        criteria: [String],
        spoken: String,
        heard: String,
        messages: [StoredMessage],
        learnt: String = "",
        observation: String = "",
        talkCount: Int = 0,
        typeCount: Int = 0,
        photoCount: Int = 0
    ) {
        self.id = id
        self.goal = goal
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.svg = svg
        self.cards = cards
        self.cardIndex = cardIndex
        self.criteria = criteria
        self.spoken = spoken
        self.heard = heard
        self.messages = messages
        self.learnt = learnt
        self.observation = observation
        self.talkCount = talkCount
        self.typeCount = typeCount
        self.photoCount = photoCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        goal = try c.decode(String.self, forKey: .goal)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        svg = try c.decode(String.self, forKey: .svg)
        cards = try c.decode([String].self, forKey: .cards)
        cardIndex = try c.decode(Int.self, forKey: .cardIndex)
        criteria = try c.decode([String].self, forKey: .criteria)
        spoken = try c.decode(String.self, forKey: .spoken)
        heard = try c.decode(String.self, forKey: .heard)
        messages = try c.decode([StoredMessage].self, forKey: .messages)
        learnt = try c.decodeIfPresent(String.self, forKey: .learnt) ?? ""
        observation = try c.decodeIfPresent(String.self, forKey: .observation) ?? ""
        talkCount = try c.decodeIfPresent(Int.self, forKey: .talkCount) ?? 0
        typeCount = try c.decodeIfPresent(Int.self, forKey: .typeCount) ?? 0
        photoCount = try c.decodeIfPresent(Int.self, forKey: .photoCount) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(goal, forKey: .goal)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(svg, forKey: .svg)
        try c.encode(cards, forKey: .cards)
        try c.encode(cardIndex, forKey: .cardIndex)
        try c.encode(criteria, forKey: .criteria)
        try c.encode(spoken, forKey: .spoken)
        try c.encode(heard, forKey: .heard)
        try c.encode(messages, forKey: .messages)
        try c.encode(learnt, forKey: .learnt)
        try c.encode(observation, forKey: .observation)
        try c.encode(talkCount, forKey: .talkCount)
        try c.encode(typeCount, forKey: .typeCount)
        try c.encode(photoCount, forKey: .photoCount)
    }
}

struct StoredMessage: Codable, Equatable {
    var role: String
    var text: String
}

enum LessonStore {
    static func load() -> [LessonRecord] {
        guard let data = try? Data(contentsOf: url()),
              let lessons = try? decoder.decode([LessonRecord].self, from: data) else {
            return []
        }
        return lessons.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func save(_ lessons: [LessonRecord]) {
        try? FileManager.default.createDirectory(at: url().deletingLastPathComponent(), withIntermediateDirectories: true)
        let trimmed = Array(lessons.sorted { $0.updatedAt > $1.updatedAt }.prefix(50))
        guard let data = try? encoder.encode(trimmed) else { return }
        try? data.write(to: url(), options: .atomic)
        ContextStore.write(trimmed)
    }

    private static func url() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Whitebored/lessons.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum ContextStore {
    static func url() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Whitebored/context.md")
    }

    static func write(_ lessons: [LessonRecord]) {
        let stamp: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter
        }()
        var lines = ["Whitebored context", ""]
        for lesson in lessons where !lesson.goal.isEmpty {
            lines.append(stamp.string(from: lesson.createdAt))
            lines.append(lesson.goal)
            lines.append("Learnt: \(lesson.learnt.isEmpty ? "still going" : lesson.learnt)")
            lines.append("How they learnt: \(lesson.styleLine)")
            lines.append("Tutor: \(lesson.observation.isEmpty ? "not enough yet" : lesson.observation)")
            lines.append("")
        }
        let text = lines.joined(separator: "\n")
        try? FileManager.default.createDirectory(at: url().deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: url(), atomically: true, encoding: .utf8)
    }

    static func read() -> String {
        (try? String(contentsOf: url(), encoding: .utf8)) ?? "no sessions yet"
    }
}
