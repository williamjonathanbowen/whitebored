import SwiftUI
import AppKit
import AVFoundation
import WebKit

struct ContentView: View {
    @Environment(Session.self) private var session
    @State private var didFullscreen = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            HStack(spacing: 0) {
                Group {
                    switch session.phase {
                    case .key:
                        KeyView()
                    case .goal:
                        GoalView()
                    case .session:
                        SessionView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if session.showHistory {
                    HistorySidebar()
                        .frame(width: 268)
                        .transition(.move(edge: .trailing))
                } else if session.showSettings {
                    SettingsSidebar()
                        .frame(width: 300)
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: session.showHistory)
            .animation(.easeInOut(duration: 0.22), value: session.showSettings)
            if session.flash {
                Color.white.opacity(0.7).ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.light)
        .background(WindowChrome())
        .onAppear {
            guard !didFullscreen else { return }
            didFullscreen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
        }
    }
}

struct KeyView: View {
    @Environment(Session.self) private var session
    @FocusState private var focused: Field?

    private enum Field {
        case anthropic
        case openai
    }

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 18) {
            Spacer()
            if Config.apiKey == nil {
                SecureField("", text: $session.keyDraft, prompt: Text("anthropic key").foregroundStyle(.black.opacity(0.25)))
                    .font(.system(size: 22, weight: .regular, design: .monospaced))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                    .focused($focused, equals: .anthropic)
                    .tint(.black)
                    .frame(maxWidth: 560)
                    .onSubmit { session.saveKeys() }
            }
            if Config.openaiKey == nil {
                SecureField("", text: $session.voiceKeyDraft, prompt: Text("openai key").foregroundStyle(.black.opacity(0.25)))
                    .font(.system(size: 22, weight: .regular, design: .monospaced))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                    .focused($focused, equals: .openai)
                    .tint(.black)
                    .frame(maxWidth: 560)
                    .onSubmit { session.saveKeys() }
            }
            Text("so i can see, think, and talk with you")
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.3))
            Spacer()
        }
        .onAppear {
            focused = Config.apiKey == nil ? .anthropic : .openai
        }
    }
}

struct GoalView: View {
    @Environment(Session.self) private var session
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 20) {
            Spacer()
            TextField(
                "",
                text: $session.goal,
                prompt: Text("what do you want to learn?").foregroundStyle(.black.opacity(0.25))
            )
            .font(session.uiFont(session.typeSize + 16))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)
            .focused($focused)
            .tint(.black)
            .frame(maxWidth: 760)
            .onSubmit {
                Task { await session.start() }
            }
            Text("one line.")
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 2) {
                HistoryToggle()
                SettingsToggle()
                FullscreenToggle()
            }
            .padding(10)
        }
        .onAppear { focused = true }
    }
}

private enum Study {
    static let ink2 = Color(red: 29 / 255, green: 33 / 255, blue: 38 / 255)
    static let muted = Color(red: 106 / 255, green: 114 / 255, blue: 128 / 255)
    static let label = Color(red: 169 / 255, green: 174 / 255, blue: 182 / 255)
    static let placeholder = Color(red: 182 / 255, green: 187 / 255, blue: 194 / 255)
    static let track = Color(red: 223 / 255, green: 227 / 255, blue: 232 / 255)
    static let hairline = Color(red: 237 / 255, green: 239 / 255, blue: 242 / 255)
    static let hairline2 = Color(red: 228 / 255, green: 231 / 255, blue: 236 / 255)
    static let fill = Color(red: 243 / 255, green: 245 / 255, blue: 247 / 255)
    static let accent = Color(red: 43 / 255, green: 82 / 255, blue: 168 / 255)
    static let record = Color(red: 255 / 255, green: 95 / 255, blue: 87 / 255)
    static let prev = Color(red: 154 / 255, green: 160 / 255, blue: 168 / 255)
    static let next = Color(red: 59 / 255, green: 64 / 255, blue: 72 / 255)
}

struct SessionView: View {
    @Environment(Session.self) private var session
    @State private var titleHover = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Color.clear
                    .frame(width: 116, height: 22)
                Spacer()
                Text(session.goal)
                    .font(session.uiFont(13))
                    .foregroundStyle(Study.label)
                    .lineLimit(1)
                    .opacity(titleHover ? 1 : 0)
                    .animation(.easeInOut(duration: 0.12), value: titleHover)
                Spacer()
                HStack(spacing: 18) {
                    NewLessonButton()
                    HistoryToggle()
                    SettingsToggle()
                    FullscreenToggle()
                }
                .foregroundStyle(Study.placeholder)
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onHover { titleHover = $0 }

            HStack(spacing: 0) {
                FlashcardsView()
                    .frame(width: 300)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Study.hairline)
                            .frame(width: 1)
                    }
                WhiteboardView(svg: session.svg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 56)
                    .padding(.vertical, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            SessionFooter()
        }
        .background(Color.white)
        .focusable()
    }
}

struct SessionFooter: View {
    @Environment(Session.self) private var session

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            CameraPeek(session: session.camera.session)
                .frame(width: 74, height: 50)
                .background(Study.track)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if !displayHeard.isEmpty {
                    Text(displayHeard)
                        .font(.system(size: 14))
                        .foregroundStyle(Study.muted)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Study.fill)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 4,
                                bottomTrailingRadius: 12,
                                topTrailingRadius: 12,
                                style: .continuous
                            )
                        )
                }
                TalkBox()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                PowerTimer()
                MicButton()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Study.hairline)
                .frame(height: 1)
        }
    }

    private var displayHeard: String {
        if !session.liveHeard.isEmpty { return session.liveHeard }
        return session.heard
    }
}

struct MicButton: View {
    @Environment(Session.self) private var session
    @State private var hover = false

    var body: some View {
        Button {
            session.toggleMute()
        } label: {
            Image(systemName: session.muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(session.muted ? Study.record : Study.accent)
                        .brightness(hover ? -0.04 : 0)
                )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeInOut(duration: 0.12), value: hover)
        .help(session.muted ? "you're muted" : "mute mic")
    }
}

struct PowerTimer: View {
    @Environment(Session.self) private var session

    var body: some View {
        Button {
            session.togglePowerTimer()
        } label: {
            Text(session.timerLabel)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Study.placeholder)
        }
        .buttonStyle(.plain)
        .help(session.timerRunning ? "stop timer" : "start a 15 minute session")
    }
}

struct ChromeIcon: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .frame(width: 17, height: 17)
            .frame(width: 22, height: 22)
    }
}

struct HistoryToggle: View {
    @Environment(Session.self) private var session

    var body: some View {
        Button {
            session.toggleHistory()
        } label: {
            ChromeIcon(name: "clock")
                .foregroundStyle(session.showHistory ? Study.ink2 : Study.placeholder)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("history")
    }
}

struct SettingsToggle: View {
    @Environment(Session.self) private var session

    var body: some View {
        Button {
            session.toggleSettings()
        } label: {
            ChromeIcon(name: "gearshape")
                .foregroundStyle(session.showSettings ? Study.ink2 : Study.placeholder)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("settings")
    }
}

struct FullscreenToggle: View {
    @State private var fullscreen = false

    var body: some View {
        Button {
            NSApp.keyWindow?.toggleFullScreen(nil)
        } label: {
            ChromeIcon(name: fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .foregroundStyle(Study.placeholder)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(fullscreen ? "exit fullscreen" : "fullscreen")
        .onAppear { sync() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            fullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            fullscreen = false
        }
    }

    private func sync() {
        fullscreen = NSApp.keyWindow?.styleMask.contains(.fullScreen) == true
    }
}

struct NewLessonButton: View {
    @Environment(Session.self) private var session

    var body: some View {
        Button {
            session.beginNew()
        } label: {
            ChromeIcon(name: "plus")
                .foregroundStyle(Study.placeholder)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("new lesson")
    }
}

struct HistorySidebar: View {
    @Environment(Session.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.black.opacity(0.55))
                Spacer()
                Button("new") {
                    session.beginNew()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundStyle(.black.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.top, 36)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)

            if session.lessons.isEmpty {
                Text("no sessions yet")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(.black.opacity(0.28))
                    .padding(18)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(session.lessons) { lesson in
                            Button {
                                Task { await session.openLesson(lesson.id) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lesson.goal)
                                        .font(.system(size: 14, weight: .regular, design: .serif))
                                        .foregroundStyle(.black.opacity(0.78))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(Self.stamp.string(from: lesson.updatedAt))
                                        .font(.system(size: 12, weight: .regular, design: .serif))
                                        .foregroundStyle(.black.opacity(0.32))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(lesson.id == session.currentLessonID ? Color.black.opacity(0.05) : Color.clear)
                            }
                            .buttonStyle(.plain)

                            Rectangle()
                                .fill(Color.black.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 18)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.96))
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

struct SettingsSidebar: View {
    @Environment(Session.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if session.showTimeline {
                    Button("settings") {
                        session.showTimeline = false
                    }
                    .buttonStyle(.plain)
                    .font(session.uiFont(13))
                    .foregroundStyle(.black.opacity(0.4))
                    Spacer()
                    Text("timeline")
                        .font(session.uiFont(15))
                        .foregroundStyle(.black.opacity(0.55))
                } else {
                    Text("settings")
                        .font(session.uiFont(15))
                        .foregroundStyle(.black.opacity(0.55))
                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 36)
            .padding(.bottom, 16)

            if session.showTimeline {
                ScrollView {
                    Text(ContextStore.read())
                        .font(session.uiFont(13))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ForEach([15.0, 18.0, 22.0], id: \.self) { size in
                            Button("\(Int(size))px") {
                                session.setTypeSize(size)
                            }
                            .buttonStyle(.plain)
                            .font(session.uiFont(13))
                            .foregroundStyle(.black.opacity(session.typeSize == size ? 0.7 : 0.32))
                        }
                    }
                    HStack(spacing: 12) {
                        ForEach(["lato", "arial", "system", "serif", "random"], id: \.self) { name in
                            Button(name) {
                                session.setTypeface(name)
                            }
                            .buttonStyle(.plain)
                            .font(session.uiFont(13))
                            .foregroundStyle(.black.opacity(session.typeface == name ? 0.7 : 0.32))
                        }
                    }
                    HStack(spacing: 12) {
                        ForEach(Config.ttsSpeeds, id: \.self) { speed in
                            Button(speed == floor(speed) ? "\(Int(speed))x" : String(format: "%gx", speed)) {
                                session.setVoiceSpeed(speed)
                            }
                            .buttonStyle(.plain)
                            .font(session.uiFont(13))
                            .foregroundStyle(.black.opacity(session.voiceSpeed == speed ? 0.7 : 0.32))
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(Config.ttsVoices, id: \.self) { name in
                            Button(name) {
                                session.setVoice(name)
                            }
                            .buttonStyle(.plain)
                            .font(session.uiFont(13))
                            .foregroundStyle(.black.opacity(session.voice == name ? 0.7 : 0.32))
                        }
                    }
                    Button("timeline") {
                        session.openTimeline()
                    }
                    .buttonStyle(.plain)
                    .font(session.uiFont(13))
                    .foregroundStyle(.black.opacity(0.4))
                }
                .padding(.horizontal, 18)
                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.96))
    }
}

struct FlashcardsView: View {
    @Environment(Session.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            Group {
                if session.cards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Study.fill)
                            .frame(width: 86, height: 11)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Study.fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Step \(session.cardIndex + 1) of \(session.cards.count)")
                            .font(.system(size: 11))
                            .tracking(1.76)
                            .textCase(.uppercase)
                            .foregroundStyle(Study.label)
                        Text(cardText)
                            .font(session.uiFont(21))
                            .foregroundStyle(Study.ink2)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(session.cards.indices, id: \.self) { index in
                    Button {
                        session.goToCard(index)
                    } label: {
                        Capsule()
                            .fill(index == session.cardIndex ? Study.accent : Study.track)
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                            .frame(height: 18, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("step \(index + 1)")
                }
            }
            .frame(height: 18)
            .padding(.top, 6)
            HStack(spacing: 10) {
                CardNavButton(label: "‹", enabled: session.cardIndex > 0, active: false) {
                    session.prevCard()
                }
                CardNavButton(label: "›", enabled: !atEnd && !session.cards.isEmpty, active: true) {
                    session.nextCard()
                }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 34)
        .animation(.easeInOut(duration: 0.18), value: session.cardIndex)
    }

    private var atEnd: Bool {
        session.cards.isEmpty || session.cardIndex >= session.cards.count - 1
    }

    private var cardText: String {
        guard session.cards.indices.contains(session.cardIndex) else { return "" }
        return session.cards[session.cardIndex]
    }
}

struct CardNavButton: View {
    let label: String
    let enabled: Bool
    let active: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(enabled ? (active ? Study.next : Study.prev) : Study.prev.opacity(0.5))
                .frame(width: 34, height: 34)
                .background(Circle().fill(hover && enabled ? Study.fill : Color.clear))
                .overlay(Circle().stroke(Study.hairline2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hover = $0 }
        .animation(.easeInOut(duration: 0.12), value: hover)
    }
}

struct TalkBox: View {
    @Environment(Session.self) private var session

    var body: some View {
        @Bindable var session = session
        ZStack(alignment: .leading) {
            if session.typedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               session.status != .thinking,
               blockedMessage == nil {
                Text("Type or talk…")
                    .font(.system(size: 15))
                    .foregroundStyle(Study.placeholder)
                    .allowsHitTesting(false)
            }
            TalkEditor(text: $session.typedDraft, font: session.nsFont(15)) {
                Task { await session.send() }
            }
            if let blockedMessage {
                Text(blockedMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Study.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 44, alignment: .leading)
        .overlay {
            if session.status == .thinking {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            }
        }
    }

    private var blockedMessage: String? {
        if case .blocked(let message) = session.status { return message }
        return nil
    }
}

struct TalkEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, font: font, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.appearance = NSAppearance(named: .aqua)

        let view = NSTextView()
        view.delegate = context.coordinator
        view.isRichText = false
        view.font = font
        view.textColor = .black
        view.insertionPointColor = .black
        view.backgroundColor = .clear
        view.drawsBackground = false
        view.appearance = NSAppearance(named: .aqua)
        view.typingAttributes = Self.typing(font)
        view.textContainerInset = NSSize(width: 0, height: 1)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.lineFragmentPadding = 0
        view.string = text
        view.isEditable = true
        view.isSelectable = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        scroll.documentView = view
        context.coordinator.view = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.font = font
        context.coordinator.onSubmit = onSubmit
        guard let view = scroll.documentView as? NSTextView else { return }
        view.appearance = NSAppearance(named: .aqua)
        view.textColor = .black
        view.insertionPointColor = .black
        view.font = font
        view.typingAttributes = Self.typing(font)
        if view.string != text {
            view.string = text
        }
    }

    private static func typing(_ font: NSFont) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: NSColor.black]
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var font: NSFont
        var onSubmit: () -> Void
        weak var view: NSTextView?

        init(text: Binding<String>, font: NSFont, onSubmit: @escaping () -> Void) {
            self.text = text
            self.font = font
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            view.textColor = .black
            view.typingAttributes = TalkEditor.typing(font)
            text.wrappedValue = view.string
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                onSubmit()
                return true
            }
            return false
        }
    }
}

struct CameraPeek: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.preview.session = session
        return view
    }

    func updateNSView(_ view: CameraPreviewView, context: Context) {
        if view.preview.session !== session {
            view.preview.session = session
        }
    }
}

struct WhiteboardView: NSViewRepresentable {
    var svg: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let web = QuietWebView()
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = context.coordinator
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        guard context.coordinator.last != svg else { return }
        context.coordinator.last = svg
        web.loadHTMLString(Self.html(svg), baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var last: String?
    }

    private static let roughJS = asset("rough")
    private static let boardJS = asset("board")

    private static func asset(_ name: String) -> String {
        guard let data = NSDataAsset(name: name)?.data,
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    private static func html(_ drawing: String) -> String {
        let trimmed = drawing.trimmingCharacters(in: .whitespacesAndNewlines)
        let picture: String
        let scripts: String
        if trimmed.hasPrefix("{") {
            let json = trimmed
                .replacingOccurrences(of: "<", with: "\\u003c")
                .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            picture = "<svg id=\"pic\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1000 700\"></svg>"
            scripts = """
            <script>\(roughJS)</script>
            <script>\(boardJS)</script>
            <script>renderBoard(\(json));</script>
            """
        } else {
            picture = trimmed.isEmpty
                ? "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1000 700\"></svg>"
                : trimmed
            scripts = ""
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: white; overflow: hidden; }
          #board { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; background: white; }
          #board svg { width: 100%; height: 100%; display: block; }
        </style>
        </head>
        <body><div id="board">\(picture)</div>\(scripts)</body>
        </html>
        """
    }
}

final class QuietWebView: WKWebView {
    override var acceptsFirstResponder: Bool { false }
}

struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        apply(view, tries: 0)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func apply(_ view: NSView, tries: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (tries == 0 ? 0 : 0.2)) {
            guard let window = view.window else {
                if tries < 10 { apply(view, tries: tries + 1) }
                return
            }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = .white
            window.appearance = NSAppearance(named: .aqua)
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
    }
}
