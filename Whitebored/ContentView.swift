import SwiftUI
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
            Text("one line. be specific.")
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 2) {
                HistoryToggle()
                SettingsToggle()
            }
            .padding(10)
        }
        .onAppear { focused = true }
    }
}

struct SessionView: View {
    @Environment(Session.self) private var session
    @State private var titleHover = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 20) {
                        if !session.cards.isEmpty {
                            FlashcardsView()
                                .frame(width: min(420, max(300, geo.size.width * 0.32)))
                        }
                        WhiteboardView(svg: session.svg)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 8)

                if !displayHeard.isEmpty {
                    Text(displayHeard)
                        .font(session.uiFont())
                        .foregroundStyle(.black.opacity(0.45))
                        .frame(maxWidth: 720, alignment: .leading)
                        .lineLimit(6)
                        .textSelection(.enabled)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                HStack(alignment: .center, spacing: 16) {
                    MicCamera(session: session)

                    TalkBox()
                        .frame(maxWidth: .infinity)

                    PowerTimer()
                        .frame(width: 132, height: 88, alignment: .center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
                .padding(.top, 8)
            }

            HStack {
                Color.clear
                    .frame(width: 116, height: 28)
                Spacer()
                Text(session.goal)
                    .font(session.uiFont(13))
                    .foregroundStyle(.black.opacity(0.4))
                    .lineLimit(1)
                    .opacity(titleHover ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: titleHover)
                Spacer()
                HStack(alignment: .center, spacing: 2) {
                    NewLessonButton()
                    HistoryToggle()
                    SettingsToggle()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onHover { titleHover = $0 }

            if session.muted {
                Text("you're muted")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(Color.red)
                    .padding(.top, 32)
            }
        }
        .background(Color.white)
        .focusable()
    }

    private var displayHeard: String {
        if !session.liveHeard.isEmpty { return session.liveHeard }
        return session.heard
    }
}

struct MicCamera: View {
    @Bindable var session: Session

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CameraPeek(session: session.camera.session)
                .frame(width: 132, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(session.muted ? Color.red : Color.black.opacity(0.08), lineWidth: session.muted ? 2 : 1)
                )
                .overlay {
                    if session.muted {
                        Color.red.opacity(0.48)
                        Text("MUTED")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                    }
                }

            Button {
                session.toggleMute()
            } label: {
                Image(systemName: session.muted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(session.muted ? .white : .black.opacity(0.55))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(session.muted ? Color.red : Color.white.opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
            .help(session.muted ? "you're muted" : "mute mic")
            .padding(6)
        }
    }
}

struct PowerTimer: View {
    @Environment(Session.self) private var session

    var body: some View {
        Button {
            session.togglePowerTimer()
        } label: {
            Text(session.timerLabel)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundStyle(.black.opacity(session.timerRunning || session.timerRemaining == 0 ? 0.55 : 0.28))
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
            .frame(width: 15, height: 15)
            .frame(width: 28, height: 28)
    }
}

struct HistoryToggle: View {
    @Environment(Session.self) private var session

    var body: some View {
        Button {
            session.toggleHistory()
        } label: {
            ChromeIcon(name: "clock")
                .foregroundStyle(.black.opacity(session.showHistory ? 0.7 : 0.5))
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
                .foregroundStyle(.black.opacity(session.showSettings ? 0.7 : 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("settings")
    }
}

struct NewLessonButton: View {
    @Environment(Session.self) private var session

    var body: some View {
        Button {
            session.beginNew()
        } label: {
            ChromeIcon(name: "plus")
                .foregroundStyle(.black.opacity(0.45))
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
        GeometryReader { geo in
            let width = max(geo.size.width - 8, 120)
            let height = min(max(geo.size.height - 36, 120), width * 0.78)
            VStack(spacing: 8) {
                ZStack {
                    ForEach(Array(stride(from: behindCount, through: 1, by: -1)), id: \.self) { depth in
                        cardFace(text: nil, width: width, height: height)
                            .offset(stackOffset(depth))
                            .rotationEffect(.degrees(stackAngle(depth)))
                    }
                    cardFace(text: cardText, width: width, height: height)
                        .onTapGesture { session.nextCard() }

                    HStack {
                        Button {
                            session.prevCard()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.black.opacity(session.cardIndex == 0 ? 0.12 : 0.4))
                                .frame(width: 28, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(session.cardIndex == 0)

                        Spacer()

                        Button {
                            session.nextCard()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.black.opacity(atEnd ? 0.12 : 0.4))
                                .frame(width: 28, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(atEnd)
                    }
                    .padding(.horizontal, 4)
                }
                .frame(width: width, height: height)
                .animation(.easeInOut(duration: 0.22), value: session.cardIndex)

                Text("\(session.cardIndex + 1) / \(session.cards.count)")
                    .font(session.uiFont(11))
                    .foregroundStyle(.black.opacity(0.28))
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private var atEnd: Bool {
        session.cardIndex >= session.cards.count - 1
    }

    private var behindCount: Int {
        min(3, max(0, session.cards.count - session.cardIndex - 1))
    }

    private var cardText: String {
        guard session.cards.indices.contains(session.cardIndex) else { return "" }
        return session.cards[session.cardIndex]
    }

    private func cardFace(text: String?, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
            if let text {
                Text(text)
                    .font(session.uiFont())
                    .foregroundStyle(.black.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(22)
            }
        }
        .frame(width: width - 18, height: height - 22)
    }

    private func stackOffset(_ depth: Int) -> CGSize {
        switch depth {
        case 1: CGSize(width: 7, height: 7)
        case 2: CGSize(width: -6, height: 13)
        default: CGSize(width: 9, height: 19)
        }
    }

    private func stackAngle(_ depth: Int) -> Double {
        switch depth {
        case 1: 2.8
        case 2: -3.6
        default: 4.4
        }
    }
}

struct TalkBox: View {
    @Environment(Session.self) private var session

    var body: some View {
        @Bindable var session = session
        ZStack {
            if session.typedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               session.status != .thinking {
                Text("type or talk, enter when you're ready")
                    .font(session.uiFont(13))
                    .foregroundStyle(.black.opacity(0.32))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            TalkEditor(text: $session.typedDraft, font: session.nsFont()) {
                Task { await session.send() }
            }
            if session.status == .thinking {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.regular)
                    .scaleEffect(1.15)
            } else if case .blocked(let message) = session.status {
                Text(message)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(.black.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 88)
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
        view.textContainerInset = NSSize(width: 4, height: 6)
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

    private static func html(_ svg: String) -> String {
        let drawing = svg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1000 700\"></svg>"
            : svg
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
        <body><div id="board">\(drawing)</div></body>
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
