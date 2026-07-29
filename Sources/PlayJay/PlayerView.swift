import SwiftUI
import UniformTypeIdentifiers
import CoreServices

private extension Color {
    static let jayBeige = Color(red: 0.76, green: 0.59, blue: 0.53) // красно-бежевый
    static let jayBlue = Color(red: 0.12, green: 0.53, blue: 0.90)  // синий
    static let jayBlack = Color(red: 0.08, green: 0.08, blue: 0.10) // черный
}

struct PlayerView: View {
    @EnvironmentObject private var player: AudioPlayerService
    @State private var isDragging = false
    @State private var dragFraction: Double = 0
    @State private var isDropTargeted = false
    @State private var isHoveringTraffic = false

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return isDragging ? dragFraction : player.currentTime / player.duration
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            progressBar
            controls
        }
        .frame(width: 320)
        .background(
            ZStack {
                Color.jayBlack
                LinearGradient(
                    colors: [
                        Color.jayBeige.opacity(0.18),
                        Color.jayBlue.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Hidden hotkey buttons isolated in the background
                Group {
                    Button {
                        let targetTime = max(player.currentTime - 10, 0)
                        let fraction = player.duration > 0 ? targetTime / player.duration : 0
                        player.seek(to: fraction)
                    } label: { EmptyView() }
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    Button {
                        let targetTime = min(player.currentTime + 10, player.duration)
                        let fraction = player.duration > 0 ? targetTime / player.duration : 0
                        player.seek(to: fraction)
                    } label: { EmptyView() }
                    .keyboardShortcut(.rightArrow, modifiers: [])

                    Button {
                        if player.state == .playing {
                            player.stop()
                        } else {
                            player.play()
                        }
                    } label: { EmptyView() }
                    .keyboardShortcut(.return, modifiers: [])
                }
                .opacity(0)
                .allowsHitTesting(false)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.jayBlue : Color.white.opacity(0.12), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            let ext = url.pathExtension.lowercased()
            guard ["mp3", "wav", "aiff", "ogg"].contains(ext) else { return false }
            
            player.loadFile(url)
            player.play()
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    private var titleBar: some View {
        HStack(spacing: 6) {
            // Close Button
            Button {
                NSApp.terminate(nil)
            } label: {
                Circle()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.6))
                            .opacity(isHoveringTraffic ? 1.0 : 0.0)
                    )
            }
            .buttonStyle(.plain)
            .help("Quit PlayJay")
            
            // Minimize Button
            Button {
                NSApp.windows.first?.miniaturize(nil)
            } label: {
                Circle()
                    .fill(Color.yellow.opacity(0.85))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "minus")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.6))
                            .opacity(isHoveringTraffic ? 1.0 : 0.0)
                    )
            }
            .buttonStyle(.plain)
            .help("Minimize")
            
            Spacer()
                .frame(width: 6)
            
            MarqueeText(
                text: player.trackName.isEmpty ? "PlayJay" : player.trackName,
                font: .system(size: 13, weight: .semibold)
            )
            
            // Settings menu
            Menu {
                Button("Set as Default Player") {
                    setAsDefaultPlayer()
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.jayBlue)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .help("Settings")
            
            Button {
                openFile()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.jayBlue)
            }
            .buttonStyle(.plain)
            .help("Open audio file")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .onHover { hovering in
            isHoveringTraffic = hovering
        }
    }

    private var progressBar: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let width = geometry.size.width
                VStack(spacing: 0) {
                    // Invisible padding that prevents window drag-n-drop (using 0.001 opacity)
                    Color.white.opacity(0.001)
                        .frame(height: 10)
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.jayBlue)
                            .frame(width: max(0, width * progress), height: 4)
                    }
                    
                    // Invisible padding that prevents window drag-n-drop (using 0.001 opacity)
                    Color.white.opacity(0.001)
                        .frame(height: 20)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragFraction = max(0, min(1, value.location.x / width))
                        }
                        .onEnded { value in
                            let fraction = max(0, min(1, value.location.x / width))
                            player.seek(to: fraction)
                            isDragging = false
                        }
                )
            }
            .frame(height: 34)

            HStack {
                Text(formatTime(player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 12, weight: .bold).monospacedDigit()) // Larger and bolder numbers!
            .foregroundStyle(Color.jayBeige.opacity(0.95))
            .padding(.top, -14) // Closer to the progress bar!
        }
        .padding(.horizontal, 14)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button { player.stop() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14))
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.25)) // Gray circular background
                    .clipShape(Circle())
                    .foregroundStyle(player.state == .stopped ? Color.white.opacity(0.3) : Color.jayBeige)
            }
            .buttonStyle(.plain)

            Button {
                switch player.state {
                case .playing: player.pause()
                case .paused, .stopped: player.play()
                }
            } label: {
                Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.jayBlue)
                    .clipShape(Circle())
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.jayBlue.opacity(0.4), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: []) // Native active spacebar play/pause
        }
        .padding(.top, -10) // Pull slightly higher closer to the timer numbers
        .padding(.bottom, 6)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.mp3, .wav, .aiff,
            UTType(filenameExtension: "ogg") ?? .audio,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .floating
        guard panel.runModal() == .OK, let url = panel.url else { return }
        player.loadFile(url)
        player.play()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func setAsDefaultPlayer() {
        let bundleID = "com.dzmitrysharko.PlayJay" as CFString
        let contentTypes = [
            "public.mp3",
            "com.microsoft.waveform-audio",
            "org.xiph.ogg-vorbis",
            "public.audio"
        ]
        
        var successCount = 0
        for contentType in contentTypes {
            let status = LSSetDefaultRoleHandlerForContentType(contentType as CFString, .viewer, bundleID)
            if status == noErr {
                successCount += 1
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "Default Player"
        if successCount > 0 {
            alert.informativeText = "PlayJay has been set as the default player for audio files."
        } else {
            alert.informativeText = "Failed to set PlayJay as the default player. Please make sure the app is in /Applications."
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct MarqueeText: View {
    let text: String
    let font: Font
    
    @State private var offset: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var timer: Timer? = nil
    
    var body: some View {
        GeometryReader { containerGeometry in
            let cWidth = containerGeometry.size.width
            
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false) // Prevents truncation
                .foregroundStyle(Color.white)
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .preference(key: WidthPreferenceKey.self, value: textGeometry.size.width)
                    }
                )
                .offset(x: offset)
                .onPreferenceChange(WidthPreferenceKey.self) { width in
                    textWidth = width
                    containerWidth = cWidth
                    resetMarquee()
                }
                .onChange(of: text) {
                    resetMarquee()
                }
                .onChange(of: containerWidth) {
                    resetMarquee()
                }
        }
        .frame(height: 20)
        .clipped()
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func resetMarquee() {
        offset = 0
        timer?.invalidate()
        timer = nil
        
        guard textWidth > containerWidth else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            DispatchQueue.main.async {
                self.startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        let scrollDistance = textWidth - containerWidth
        let duration = Double(scrollDistance) / 30.0 // Constant speed (30px/sec)
        
        withAnimation(.linear(duration: duration)) {
            offset = -scrollDistance
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: duration + 1.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.offset = 0
                }
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.3, repeats: false) { _ in
                    DispatchQueue.main.async {
                        self.startAnimation()
                    }
                }
            }
        }
    }
}

struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
