import SwiftUI

struct ActiveCuesView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Active Cues", systemImage: "play.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Spacer()
            if !audioEngine.activeCues.isEmpty {
                Text("\(audioEngine.activeCues.count) playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    audioEngine.stopAll()
                } label: {
                    Label("Stop All", systemImage: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if audioEngine.activeCues.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(audioEngine.activeCues) { cue in
                        ActiveCueCard(cue: cue)
                    }
                }
                .padding(10)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "play.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No cues playing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

// MARK: - Active Cue Card

struct ActiveCueCard: View {
    @EnvironmentObject var audioEngine: AudioEngine
    var cue: PlaybackState

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(cue.color.nsColor))
                    .frame(width: 4, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(cue.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(cue.currentTime.formattedTime)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("/")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(cue.totalDuration.formattedTime)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("-\(cue.timeRemaining.formattedTime)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                // Volume control
                HStack(spacing: 4) {
                    Image(systemName: cue.isDucked ? "speaker.slash" : "speaker.wave.2")
                        .font(.system(size: 10))
                        .foregroundStyle(cue.isDucked ? .orange : .secondary)
                    Slider(value: Binding(
                        get: { Float(cue.volume) },
                        set: { audioEngine.setVolume($0, forCueID: cue.id) }
                    ), in: 0...1)
                    .frame(width: 60)
                }

                // Stop button
                Button {
                    audioEngine.stopCue(id: cue.id)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("Stop this cue")
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(cue.color.nsColor))
                        .frame(width: max(geo.size.width * cue.progress, 0), height: 6)
                        .animation(.linear(duration: 0.1), value: cue.progress)
                }
            }
            .frame(height: 6)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(cue.color.nsColor).opacity(0.4), lineWidth: 1)
                )
        )
    }
}
