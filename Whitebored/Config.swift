import Foundation

enum Config {
    static let model = "claude-sonnet-5"
    static let ttsModel = "gpt-4o-mini-tts"
    static let ttsVoice = "ash"
    static let ttsSpeeds: [Double] = [1, 1.25, 1.5, 1.75, 2]
    static let ttsVoices = [
        "alloy", "ash", "ballad", "coral", "echo", "fable",
        "nova", "onyx", "sage", "shimmer", "verse", "marin", "cedar",
    ]

    static var apiKey: String? { read("ANTHROPIC_API_KEY", defaults: "anthropicKey", file: "key") }
    static var openaiKey: String? { read("OPENAI_API_KEY", defaults: "openaiKey", file: "openai_key") }

    static var needsKeys: Bool { apiKey == nil || openaiKey == nil }

    static func bootstrap() {
        if let key = apiKey { saveAnthropic(key) }
        if let key = openaiKey { saveOpenAI(key) }
    }

    static func saveAnthropic(_ key: String) {
        write(key, defaults: "anthropicKey", file: "key")
    }

    static func saveOpenAI(_ key: String) {
        write(key, defaults: "openaiKey", file: "openai_key")
    }

    private static func read(_ env: String, defaults: String, file: String) -> String? {
        if let value = clean(ProcessInfo.processInfo.environment[env]) {
            return value
        }
        if let saved = clean(UserDefaults.standard.string(forKey: defaults)) {
            return saved
        }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/whitebored/\(file)")
        if let raw = try? String(contentsOf: url, encoding: .utf8), let value = clean(raw) {
            return value
        }
        return fromLoginShell(env)
    }

    private static func write(_ key: String, defaults: String, file: String) {
        guard let trimmed = clean(key) else { return }
        UserDefaults.standard.set(trimmed, forKey: defaults)
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/whitebored")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? trimmed.write(to: dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    private static func fromLoginShell(_ name: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lic", "printenv \(name)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            return nil
        }
        let deadline = Date().addingTimeInterval(2)
        while task.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if task.isRunning { task.terminate() }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return clean(String(data: data, encoding: .utf8))
    }

    private static func clean(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isNewline) else { return nil }
        return trimmed
    }
}
