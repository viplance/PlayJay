import AVFoundation
import Combine
import MediaPlayer

enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
}

@MainActor
final class AudioPlayerService: ObservableObject {
    @Published private(set) var state: PlaybackState = .stopped
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var trackName: String = ""

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var sampleRate: Double = 44100
    private var seekOffset: AVAudioFramePosition = 0
    private var isSeeking = false
    private var currentSessionID = 0
    private var timer: AnyCancellable?

    init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        setupRemoteCommandCenter()
    }

    func loadFile(_ url: URL) {
        stop()

        guard let file = try? AVAudioFile(forReading: url) else { return }
        audioFile = file
        sampleRate = file.processingFormat.sampleRate
        duration = Double(file.length) / sampleRate
        trackName = url.deletingPathExtension().lastPathComponent
        seekOffset = 0
        currentTime = 0
        updateNowPlayingInfo()
    }

    func play() {
        guard let file = audioFile else { return }

        if state == .paused {
            playerNode.play()
            state = .playing
            startTimer()
            updateNowPlayingInfo()
            return
        }

        currentSessionID += 1
        let startFrame = seekOffset
        isSeeking = true
        playerNode.stop()
        isSeeking = false
        scheduleFile(file, from: startFrame)

        if !engine.isRunning { try? engine.start() }
        playerNode.play()
        state = .playing
        startTimer()
        updateNowPlayingInfo()
    }

    func pause() {
        guard state == .playing else { return }
        playerNode.pause()
        state = .paused
        stopTimer()
        updateNowPlayingInfo()
    }

    func stop() {
        currentSessionID += 1
        playerNode.stop()
        engine.stop()
        state = .stopped
        seekOffset = 0
        currentTime = 0
        stopTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to fraction: Double) {
        guard let file = audioFile else { return }
        let targetFrame = AVAudioFramePosition(fraction * Double(file.length))
        let wasPlaying = state == .playing

        currentSessionID += 1
        isSeeking = true
        playerNode.stop()
        isSeeking = false

        scheduleFile(file, from: targetFrame)
        currentTime = fraction * duration

        if wasPlaying {
            if !engine.isRunning { try? engine.start() }
            playerNode.play()
            state = .playing
            startTimer()
        }
        updateNowPlayingInfo()
    }

    private func scheduleFile(_ file: AVAudioFile, from startFrame: AVAudioFramePosition) {
        let frameCount = AVAudioFrameCount(file.length - startFrame)
        guard frameCount > 0 else { return }

        file.framePosition = startFrame
        seekOffset = startFrame

        let sessionID = currentSessionID
        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil
        ) { [weak self] in
            Task { @MainActor in
                self?.onPlaybackFinished(sessionID: sessionID)
            }
        }
    }

    private func onPlaybackFinished(sessionID: Int) {
        guard state == .playing, sessionID == currentSessionID else { return }
        stop()
    }

    private func startTimer() {
        timer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateTime() }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func updateTime() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return }
        currentTime = (Double(seekOffset) + Double(playerTime.sampleTime)) / sampleRate
        if currentTime >= duration {
            stop()
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play Command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.play()
            }
            return .success
        }

        // Pause Command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.pause()
            }
            return .success
        }

        // Toggle Play/Pause Command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                switch self.state {
                case .playing: self.pause()
                case .paused, .stopped: self.play()
                }
            }
            return .success
        }

        // Stop Command
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.stop()
            }
            return .success
        }

        // Skip Forward Command (fast forward)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                let targetTime = min(self.currentTime + 10, self.duration)
                let fraction = self.duration > 0 ? targetTime / self.duration : 0
                self.seek(to: fraction)
            }
            return .success
        }

        // Skip Backward Command (rewind)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                let targetTime = max(self.currentTime - 10, 0)
                let fraction = self.duration > 0 ? targetTime / self.duration : 0
                self.seek(to: fraction)
            }
            return .success
        }

        // Next Track Command (maps to skip forward 10s)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                let targetTime = min(self.currentTime + 10, self.duration)
                let fraction = self.duration > 0 ? targetTime / self.duration : 0
                self.seek(to: fraction)
            }
            return .success
        }

        // Previous Track Command (maps to skip backward 10s)
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                let targetTime = max(self.currentTime - 10, 0)
                let fraction = self.duration > 0 ? targetTime / self.duration : 0
                self.seek(to: fraction)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let _ = audioFile else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        let info: [String: Any] = [
            MPMediaItemPropertyTitle: trackName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}