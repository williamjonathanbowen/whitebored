import SwiftUI
import AVFoundation
import WebKit

struct ContentView: View {
    @Environment(Session.self) private var session
    @State private var didFullscreen = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            switch session.phase {
            case .key:
                KeyView()
            case .goal:
                GoalView()
            case .session:
                SessionView()
            }
            if session.flash {
                Color.white.opacity(0.7).ignoresSafeArea().allowsHitTesting(false)
            }
        }
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
            .font(.system(size: 34, weight: .regular, design: .serif))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
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
        .onAppear { focused = true }
    }
}

struct SessionView: View {
    @Environment(Session.self) private var session

    var body: some View {
        VStack(spacing: 0) {
            Text(session.goal)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundStyle(.black.opacity(0.28))
                .lineLimit(1)
                .padding(.top, 36)
                .padding(.horizontal, 40)

            WhiteboardView(svg: session.svg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
                .padding(.vertical, 8)

            if !session.spoken.isEmpty {
                Text(session.spoken)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(.black.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                    .frame(maxWidth: 780)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 8)
            }

            Text(displayHeard)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(.black.opacity(0.38))
                .lineLimit(3)
                .frame(maxWidth: 720)
                .padding(.horizontal, 24)
                .opacity(displayHeard.isEmpty ? 0 : 1)

            HStack(alignment: .center, spacing: 16) {
                CameraPeek(session: session.camera.session)
                    .frame(width: 132, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                Spacer()

                VStack(spacing: 6) {
                    Text(statusText)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundStyle(.black.opacity(session.status == .thinking ? 0.55 : 0.32))
                    Text("To make me talk, press Option-Command")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(.black.opacity(0.28))
                }

                Spacer()

                Color.clear
                    .frame(width: 132, height: 88)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 22)
            .padding(.top, 10)
        }
        .background(Color.white)
        .focusable()
    }

    private var displayHeard: String {
        if !session.liveHeard.isEmpty { return session.liveHeard }
        return session.heard
    }

    private var statusText: String {
        switch session.status {
        case .silent: return "stay silent"
        case .thinking: return "thinking"
        case .speaking: return session.spoken.isEmpty ? "speaking" : ""
        case .blocked(let message): return message
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
        """
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          html, body { margin: 0; height: 100%; background: white; }
          body { display: flex; align-items: center; justify-content: center; }
          svg { width: min(100%, 1100px); height: min(100%, 78vh); }
        </style>
        </head>
        <body>\(svg)</body>
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
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
    }
}
