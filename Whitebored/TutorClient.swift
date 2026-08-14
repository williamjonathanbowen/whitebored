import AppKit
import Foundation

struct TutorReply: Equatable {
    var speak: String
    var svg: String
    var criteria: [String]
    var mode: String
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
        case .decode(let raw): return "could not read tutor json: \(raw)"
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
    static func complete(messages: [ChatMessage]) async throws -> TutorReply {
        guard let key = Config.apiKey else { throw TutorError.missingKey }

        let payload: [String: Any] = [
            "model": Config.model,
            "max_tokens": 4096,
            "thinking": ["type": "disabled"],
            "system": SystemPrompt.text,
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
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = obj["error"] as? [String: Any],
               let message = err["message"] as? String {
                throw TutorError.http(status, message)
            }
            throw TutorError.http(status, String(snippet.prefix(240)))
        }

        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if parsed?["stop_reason"] as? String == "refusal" {
            throw TutorError.refused
        }
        let content = parsed?["content"] as? [[String: Any]] ?? []
        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw TutorError.empty }
        return try decodeReply(text)
    }

    static func decodeReply(_ raw: String) throws -> TutorReply {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let startFence = s.range(of: "```json") ?? s.range(of: "```JSON") ?? (s.hasPrefix("```") ? s.range(of: "```") : nil) {
            s = String(s[startFence.upperBound...])
            if let end = s.range(of: "```") {
                s = String(s[..<end.lowerBound])
            }
        }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            s = String(s[start...end])
        }
        guard let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let speak = obj["speak"] as? String else {
            throw TutorError.decode(String(raw.prefix(200)))
        }
        let svg = (obj["svg"] as? String) ?? (obj["whiteboardSVG"] as? String) ?? ""
        let criteria = obj["criteria"] as? [String] ?? obj["successCriteria"] as? [String] ?? []
        let mode = obj["mode"] as? String ?? "nudge"
        return TutorReply(speak: speak, svg: wrappedSVG(svg), criteria: criteria, mode: mode)
    }

    static func wrappedSVG(_ svg: String) -> String {
        let trimmed = svg.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 700"></svg>
            """
        }
        if trimmed.lowercased().contains("<svg") { return trimmed }
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 700">\(trimmed)</svg>
        """
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
