import AppKit
import Foundation

struct TutorReply: Equatable {
    var speak: String
    var svg: String
    var criteria: [String]
    var mode: String
    var learnt: String
    var observe: String
}

enum TutorError: LocalizedError {
    case missingKey
    case http(Int, String)
    case empty
    case refused
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "missing anthropic key"
        case .http(let code, let body): return "tutor error \(code): \(body)"
        case .empty: return "the tutor said nothing"
        case .refused: return "the tutor refused that turn"
        case .decode(_): return "the tutor got confused. press enter again."
        }
    }
}

struct ChatMessage {
    var role: String
    var blocks: [ContentBlock]
}

enum ContentBlock {
    case text(String)
    case jpeg(Data)
}

enum TutorClient {
    static func complete(
        messages: [ChatMessage],
        onSpeak: ((String) async -> Void)? = nil
    ) async throws -> TutorReply {
        guard let key = Config.apiKey else { throw TutorError.missingKey }

        let payload: [String: Any] = [
            "model": Config.model,
            "max_tokens": 8192,
            "stream": true,
            "thinking": ["type": "disabled"],
            "tool_choice": ["type": "tool", "name": "tutor_turn"],
            "tools": [
                [
                    "name": "tutor_turn",
                    "description": "Speak to the learner and update the whiteboard.",
                    "input_schema": [
                        "type": "object",
                        "properties": [
                            "speak": [
                                "type": "string",
                                "description": "3 to 8 short spoken sentences."
                            ],
                            "svg": [
                                "type": "string",
                                "description": "Complete SVG markup. Must start with <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1000 700'> and include real shapes: circle, line, rect, path, text. Never empty. No scripts, images, or foreignObject."
                            ],
                            "criteria": [
                                "type": "array",
                                "items": ["type": "string"]
                            ],
                            "mode": [
                                "type": "string",
                                "enum": ["explain", "nudge", "challenge", "celebrate"]
                            ],
                            "learnt": [
                                "type": "string",
                                "description": "One line: what they understand so far this session."
                            ],
                            "observe": [
                                "type": "string",
                                "description": "One sentence about how this student likes to learn, from the session so far."
                            ]
                        ],
                        "required": ["speak", "svg"]
                    ]
                ]
            ],
            "system": [
                [
                    "type": "text",
                    "text": SystemPrompt.text,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": messages.map { message in
                [
                    "role": message.role,
                    "content": message.blocks.map { block -> [String: Any] in
                        switch block {
                        case .text(let text):
                            return ["type": "text", "text": text]
                        case .jpeg(let data):
                            return [
                                "type": "image",
                                "source": [
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": data.base64EncodedString()
                                ]
                            ]
                        }
                    }
                ]
            }
        ]

        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 90

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            let data = try await bytes.reduce(into: Data()) { $0.append($1) }
            let snippet = String(data: data, encoding: .utf8) ?? ""
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = obj["error"] as? [String: Any],
               let message = err["message"] as? String {
                throw TutorError.http(status, message)
            }
            throw TutorError.http(status, String(snippet.prefix(240)))
        }

        var json = ""
        var text = ""
        var spoke = false
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let chunk = String(line.dropFirst(6))
            if chunk == "[DONE]" { break }
            guard let obj = try? JSONSerialization.jsonObject(with: Data(chunk.utf8)) as? [String: Any],
                  let type = obj["type"] as? String else { continue }
            if type == "error" {
                let message = ((obj["error"] as? [String: Any])?["message"] as? String) ?? chunk
                throw TutorError.http(status, message)
            }
            if type == "message_stop" { break }
            guard type == "content_block_delta",
                  let delta = obj["delta"] as? [String: Any],
                  let deltaType = delta["type"] as? String else { continue }
            if deltaType == "input_json_delta", let piece = delta["partial_json"] as? String {
                json += piece
            } else if deltaType == "text_delta", let piece = delta["text"] as? String {
                text += piece
            } else {
                continue
            }
            let soFar = json.isEmpty ? text : json
            if !spoke, let speak = extractSpeak(soFar), !speak.isEmpty {
                spoke = true
                await onSpeak?(speak)
            }
        }
        let raw = (json.isEmpty ? text : json).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { throw TutorError.empty }
        return try decodeReply(raw)
    }

    static func extractSpeak(_ partial: String) -> String? {
        extractJSONString(named: "speak", from: partial, allowIncomplete: false)
    }

    static func extractJSONString(named name: String, from partial: String, allowIncomplete: Bool) -> String? {
        let needle = "\"\(name)\""
        var search = partial.startIndex
        while let key = partial.range(of: needle, range: search..<partial.endIndex) {
            var i = key.upperBound
            while i < partial.endIndex, partial[i].isWhitespace { i = partial.index(after: i) }
            if i < partial.endIndex, partial[i] == ":" {
                i = partial.index(after: i)
                while i < partial.endIndex, partial[i].isWhitespace { i = partial.index(after: i) }
                guard i < partial.endIndex, partial[i] == "\"" else { return nil }
                i = partial.index(after: i)
                var out = ""
                var escaped = false
                while i < partial.endIndex {
                    let c = partial[i]
                    if escaped {
                        switch c {
                        case "n": out.append("\n")
                        case "t": out.append("\t")
                        case "r": out.append("\r")
                        case "\"": out.append("\"")
                        case "\\": out.append("\\")
                        case "/": out.append("/")
                        default: out.append(c)
                        }
                        escaped = false
                    } else if c == "\\" {
                        escaped = true
                    } else if c == "\"" {
                        return out
                    } else {
                        out.append(c)
                    }
                    i = partial.index(after: i)
                }
                return allowIncomplete ? out : nil
            }
            search = key.upperBound
        }
        return nil
    }

    static func decodeReply(_ raw: String) throws -> TutorReply {
        let cleaned = stripFences(raw)
        let obj = jsonObject(cleaned)
        let speak = (obj?["speak"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? extractJSONString(named: "speak", from: raw, allowIncomplete: false)
            ?? extractJSONString(named: "speak", from: cleaned, allowIncomplete: false)
            ?? looseSpeak(cleaned)
        var svg = (obj?["svg"] as? String)
            ?? (obj?["whiteboardSVG"] as? String)
            ?? extractJSONString(named: "svg", from: raw, allowIncomplete: true)
            ?? extractJSONString(named: "svg", from: cleaned, allowIncomplete: true)
            ?? extractSVG(raw)
        svg = sanitizeSVG(svg)
        if speak.isEmpty && svg.isEmpty {
            throw TutorError.decode(String(raw.prefix(200)))
        }
        let criteria: [String]
        if let list = obj?["criteria"] as? [String] {
            criteria = list
        } else if let list = obj?["successCriteria"] as? [String] {
            criteria = list
        } else if let one = obj?["criteria"] as? String, !one.isEmpty {
            criteria = [one]
        } else {
            criteria = []
        }
        return TutorReply(
            speak: speak.isEmpty ? "have a look at the board." : speak,
            svg: svg,
            criteria: criteria,
            mode: obj?["mode"] as? String ?? "explain",
            learnt: (obj?["learnt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? extractJSONString(named: "learnt", from: raw, allowIncomplete: false)
                ?? "",
            observe: (obj?["observe"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? extractJSONString(named: "observe", from: raw, allowIncomplete: false)
                ?? ""
        )
    }

    static func hasInk(_ svg: String) -> Bool {
        !sanitizeSVG(svg).isEmpty
    }

    static func sanitizeSVG(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        if s.contains("\\\"") || s.contains("\\n") || s.contains("\\/") {
            s = jsonUnescape(s)
        }
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&apos;", with: "'")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        guard let start = s.range(of: "<svg", options: .caseInsensitive) else { return "" }
        s = String(s[start.lowerBound...])
        if let end = s.range(of: "</svg>", options: .caseInsensitive) {
            s = String(s[..<end.upperBound])
        } else {
            s += "</svg>"
        }
        s = s.replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<foreignObject[\\s\\S]*?</foreignObject>", with: "", options: [.regularExpression, .caseInsensitive])
        if !s.lowercased().contains("xmlns") {
            s = s.replacingOccurrences(of: "<svg", with: "<svg xmlns=\"http://www.w3.org/2000/svg\"", options: .caseInsensitive)
        }
        if !s.lowercased().contains("viewbox") {
            s = s.replacingOccurrences(of: "<svg", with: "<svg viewBox=\"0 0 1000 700\"", options: .caseInsensitive)
        }
        let lower = s.lowercased()
        let marks = ["<circle", "<rect", "<line", "<path", "<text", "<ellipse", "<polygon", "<polyline", "<g"]
        guard marks.contains(where: { lower.contains($0) }) else { return "" }
        return s
    }

    private static func jsonUnescape(_ s: String) -> String {
        var out = ""
        var escaped = false
        for c in s {
            if escaped {
                switch c {
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "r": out.append("\r")
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                case "/": out.append("/")
                default: out.append(c)
                }
                escaped = false
            } else if c == "\\" {
                escaped = true
            } else {
                out.append(c)
            }
        }
        return out
    }

    private static func stripFences(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let startFence = s.range(of: "```json") ?? s.range(of: "```JSON") ?? (s.hasPrefix("```") ? s.range(of: "```") : nil) {
            s = String(s[startFence.upperBound...])
            if let end = s.range(of: "```") {
                s = String(s[..<end.lowerBound])
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func jsonObject(_ s: String) -> [String: Any]? {
        if let data = s.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        let repaired = s.replacingOccurrences(of: ",\\s*([}\\]])", with: "$1", options: .regularExpression)
        if let data = repaired.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        return nil
    }

    static func extractSVG(_ raw: String) -> String {
        let lower = raw.lowercased()
        guard let start = lower.range(of: "<svg") else { return "" }
        let from = raw[start.lowerBound...]
        if let end = from.range(of: "</svg>", options: .caseInsensitive) {
            return String(from[..<end.upperBound])
        }
        return String(from) + "</svg>"
    }

    private static func looseSpeak(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("{") { return "" }
        if let svg = s.range(of: "<svg", options: .caseInsensitive) {
            s = String(s[..<svg.lowerBound])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func wrappedSVG(_ svg: String) -> String {
        sanitizeSVG(svg)
    }

    static func jpegFitting(_ data: Data, maxSide: CGFloat = 1280, quality: CGFloat = 0.72) -> Data {
        guard let image = NSImage(data: data) else { return data }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return data }
        let scale = min(1, maxSide / max(size.width, size.height))
        let out = NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(out.width),
            pixelsHigh: Int(out.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return data }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: out), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) ?? data
    }
}
