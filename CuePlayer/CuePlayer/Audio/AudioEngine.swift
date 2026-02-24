import Foundation
import AVFoundation
import AppKit
import Combine

// MARK: - Playback State

struct PlaybackState: Identifiable {
    var id: String           // cue UUID
    var displayName: String
    var color: String
    var totalDuration: Double
    var currentTime: Double = 0
    var volume: Double = 1.0
    var isDucked: Bool = false
    var playerNode: AVAudioPlayerNode
    var gainNode: AVAudioMixerNode
    var startDate: Date = Date()
    var startOffset: Double = 0  // inPoint

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(currentTime / totalDuration, 1.0)
    }

    var timeRemaining: Double {
        max(totalDuration - currentTime, 0)
    }
}

// MARK: - Audio Engine

@MainActor
final class AudioEngine: ObservableObject {
    @Published var activeCues: [PlaybackState] = []
    @Published var masterVolume: Float = 1.0 {
        didSet { engine.mainMixerNode.outputVolume = masterVolume }
    }

    private let engine = AVAudioEngine()
    private var timer: Timer?
    private var duckGain: AVAudioMixerNode?

    init() {
        setupEngine()
        startProgressTimer()
    }

    // MARK: - Setup

    private func setupEngine() {
        do {
            try engine.start()
        } catch {
            print("AudioEngine start failed: \(error)")
        }
    }

    private func startProgressTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func updateProgress() {
        var toRemove: [String] = []
        for i in activeCues.indices {
            let elapsed = Date().timeIntervalSince(activeCues[i].startDate)
            activeCues[i].currentTime = activeCues[i].startOffset + elapsed
            if activeCues[i].currentTime >= activeCues[i].totalDuration {
                toRemove.append(activeCues[i].id)
            }
        }
        for id in toRemove {
            cleanupCue(id: id)
        }
    }

    // MARK: - Play

    func playCue(_ cue: AudioCue, project: Project) {
        // Ducking logic
        switch cue.duckingBehavior.mode {
        case .stopAll:
            stopAll()
        case .duckOthers:
            duckActive(level: Float(cue.duckingBehavior.duckLevel))
        case .noDucking:
            break
        }

        guard !cue.mediaPath.isEmpty else { return }
        let url = URL(fileURLWithPath: cue.mediaPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let audioFile = try AVAudioFile(forReading: url)
            let playerNode = AVAudioPlayerNode()
            let gainNode   = AVAudioMixerNode()
            gainNode.outputVolume = Float(cue.volume)

            engine.attach(playerNode)
            engine.attach(gainNode)
            engine.connect(playerNode, to: gainNode, format: audioFile.processingFormat)
            engine.connect(gainNode, to: engine.mainMixerNode, format: audioFile.processingFormat)

            if !engine.isRunning {
                try engine.start()
            }

            let inFrame  = AVAudioFramePosition(cue.inPoint * audioFile.processingFormat.sampleRate)
            let outFrame = AVAudioFramePosition(cue.outPoint * audioFile.processingFormat.sampleRate)
            let frameCount = AVAudioFrameCount(max(outFrame - inFrame, 0))

            // Fade in
            if cue.playFade > 0 {
                gainNode.outputVolume = 0
                let targetVolume = Float(cue.volume)
                let fadeFrames = Int(cue.playFade * 10)
                let step = targetVolume / Float(fadeFrames)
                DispatchQueue.global().async {
                    for i in 0..<fadeFrames {
                        Thread.sleep(forTimeInterval: 0.1)
                        DispatchQueue.main.async {
                            gainNode.outputVolume = min(step * Float(i + 1), targetVolume)
                        }
                    }
                }
            }

            // Use scheduleSegment to respect both in and out points
            playerNode.scheduleSegment(audioFile,
                                       startingFrame: inFrame,
                                       frameCount: frameCount,
                                       at: nil)
            playerNode.play()

            let effectiveDuration = cue.outPoint - cue.inPoint

            var state = PlaybackState(
                id: cue.id,
                displayName: cue.displayName,
                color: cue.color,
                totalDuration: effectiveDuration,
                volume: cue.volume,
                playerNode: playerNode,
                gainNode: gainNode,
                startDate: Date(),
                startOffset: 0
            )
            activeCues.append(state)

            // Handle end behavior after playback completes
            let endBehavior = cue.endBehavior
            let cueID = cue.id
            DispatchQueue.main.asyncAfter(deadline: .now() + effectiveDuration) { [weak self] in
                guard let self, self.activeCues.contains(where: { $0.id == cueID }) else { return }
                self.handleEndBehavior(cueID: cueID, endBehavior: endBehavior, project: project)
            }

        } catch {
            print("Error playing cue \(cue.displayName): \(error)")
        }

        // Handle start behavior
        switch cue.startBehavior.action {
        case .playNext:
            if let next = project.findNextAudioCue(after: cue.id) {
                playCue(next, project: project)
            }
        case .playItem:
            if let targetID = cue.startBehavior.targetUUID,
               let target = project.findAudioCue(byID: targetID) {
                playCue(target, project: project)
            }
        case .nothing:
            break
        }
    }

    private func handleEndBehavior(cueID: String, endBehavior: EndBehavior, project: Project) {
        cleanupCue(id: cueID)
        switch endBehavior.action {
        case .next:
            if let next = project.findNextAudioCue(after: cueID) {
                playCue(next, project: project)
            }
        case .gotoItem:
            if let targetID = endBehavior.targetUUID,
               let target = project.findAudioCue(byID: targetID) {
                playCue(target, project: project)
            }
        case .loop:
            if let cue = project.findAudioCue(byID: cueID) {
                playCue(cue, project: project)
            }
        case .nothing:
            break
        }
    }

    // MARK: - Stop

    func stopCue(id: String, fadeOut: Double = 1.0) {
        guard let idx = activeCues.firstIndex(where: { $0.id == id }) else { return }
        let gainNode = activeCues[idx].gainNode  // capture gainNode directly, not the whole state

        if fadeOut > 0 {
            let steps = Int(fadeOut * 10)
            let startVol = gainNode.outputVolume
            let step = startVol / Float(steps)
            for i in 0..<steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    gainNode.outputVolume = max(startVol - step * Float(i + 1), 0)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) { [weak self] in
                self?.cleanupCue(id: id)
            }
        } else {
            cleanupCue(id: id)
        }
    }

    func stopAll(fadeOut: Double = 1.0) {
        let ids = activeCues.map { $0.id }
        for id in ids {
            stopCue(id: id, fadeOut: fadeOut)
        }
    }

    private func cleanupCue(id: String) {
        guard let idx = activeCues.firstIndex(where: { $0.id == id }) else { return }
        let state = activeCues[idx]
        state.playerNode.stop()
        engine.detach(state.playerNode)
        engine.detach(state.gainNode)
        activeCues.remove(at: idx)
    }

    // MARK: - Ducking

    private func duckActive(level: Float) {
        for i in activeCues.indices {
            activeCues[i].isDucked = true
            let target = level
            let current = activeCues[i].gainNode.outputVolume
            let steps = 5
            let step = (current - target) / Float(steps)
            let gainNode = activeCues[i].gainNode
            for j in 0..<steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(j) * 0.05) {
                    gainNode.outputVolume = max(current - step * Float(j + 1), target)
                }
            }
        }
    }

    func unduckAll() {
        for i in activeCues.indices where activeCues[i].isDucked {
            let target = Float(activeCues[i].volume)
            let gainNode = activeCues[i].gainNode
            let steps = 10
            let current = gainNode.outputVolume
            let step = (target - current) / Float(steps)
            for j in 0..<steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(j) * 0.1) {
                    gainNode.outputVolume = min(current + step * Float(j + 1), target)
                }
            }
            activeCues[i].isDucked = false
        }
    }

    // MARK: - Volume

    func setVolume(_ volume: Float, forCueID id: String) {
        guard let idx = activeCues.firstIndex(where: { $0.id == id }) else { return }
        activeCues[idx].gainNode.outputVolume = volume
        activeCues[idx].volume = Double(volume)
    }

    // MARK: - Is Playing

    func isPlaying(_ id: String) -> Bool {
        activeCues.contains { $0.id == id }
    }

    deinit {
        timer?.invalidate()
        engine.stop()
    }
}
