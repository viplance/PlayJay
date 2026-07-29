import AppKit
import SwiftUI

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false // Fix to remove black window corners!
            window.hasShadow = false // Completely disable system rectangular shadow to remove black borders!
            window.setFrameAutosaveName("PlayJayMainWindow")
            
            // Force a 100% borderless window style in AppKit, removing the native title bar completely
            window.styleMask = [.borderless, .fullSizeContentView, .miniaturizable]
            
            // Completely hide the original non-working system title bar buttons
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            
            // Traverse subviews and hide any NSVisualEffectView to completely remove the semi-transparent frosted background
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = .clear
                
                @MainActor func hideVisualEffects(in subview: NSView) {
                    if subview is NSVisualEffectView {
                        subview.isHidden = true
                    }
                    for child in subview.subviews {
                        hideVisualEffects(in: child)
                    }
                }
                
                // Defer slightly to allow SwiftUI to finish building its native view hierarchy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    hideVisualEffects(in: contentView)
                }
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

@main
struct PlayJayApp: App {
    @StateObject private var player = AudioPlayerService()

    var body: some Scene {
        Window("PlayJay", id: "main") {
            PlayerView()
                .environmentObject(player)
                .background(WindowAccessor())
                .onOpenURL { url in
                    player.loadFile(url)
                    player.play()
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
