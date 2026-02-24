import SwiftUI
import AVFoundation

// MARK: - Waveform View

struct WaveformView: View {
    var audioURL: URL?
    var inPoint: Double = 0
    var outPoint: Double = 0
    var duration: Double = 0
    var accentColor: Color = .accentColor

    @State private var samples: [Float] = []
    @State private var isLoading = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if samples.isEmpty {
                    emptyState
                } else {
                    waveformCanvas(size: geo.size)
                }
                // In/Out point overlays
                if duration > 0 {
                    inOutOverlay(size: geo.size)
                }
            }
        }
        .task(id: audioURL) {
            await loadWaveform()
        }
    }

    // MARK: - Waveform Canvas

    private func waveformCanvas(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let count = samples.count
            guard count > 0 else { return }
            let barWidth = canvasSize.width / CGFloat(count)
            let midY = canvasSize.height / 2

            for (i, sample) in samples.enumerated() {
                let x = CGFloat(i) * barWidth
                let h = max(CGFloat(sample) * canvasSize.height * 0.9, 1)
                let rect = CGRect(x: x, y: midY - h / 2, width: max(barWidth - 0.5, 0.5), height: h)

                // Dim samples outside in/out range
                let sampleTime = duration * Double(i) / Double(count)
                let isActive = sampleTime >= inPoint && sampleTime <= outPoint

                context.fill(Path(rect), with: .color(accentColor.opacity(isActive ? 0.85 : 0.2)))
            }
        }
    }

    // MARK: - In/Out Overlay

    private func inOutOverlay(size: CGSize) -> some View {
        let inX  = CGFloat(inPoint  / duration) * size.width
        let outX = CGFloat(outPoint / duration) * size.width

        return ZStack(alignment: .leading) {
            // Dimmed before in point
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .frame(width: inX)

            // Dimmed after out point
            HStack {
                Spacer().frame(width: outX)
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: size.width - outX)
            }

            // In point marker
            Rectangle()
                .fill(Color.green)
                .frame(width: 2)
                .offset(x: inX)

            // Out point marker
            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
                .offset(x: outX - 2)
        }
        .frame(height: size.height)
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "waveform.slash")
                .foregroundStyle(.secondary)
            Text("No audio file")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load Waveform

    private func loadWaveform() async {
        guard let url = audioURL else {
            await MainActor.run { samples = [] }
            return
        }
        await MainActor.run { isLoading = true; samples = [] }

        let extracted = await Task.detached(priority: .utility) {
            Self.extractSamples(from: url, count: 300)
        }.value

        await MainActor.run {
            samples = extracted
            isLoading = false
        }
    }

    private static func extractSamples(from url: URL, count: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: file.processingFormat.sampleRate,
                                   channels: 1,
                                   interleaved: false)
        guard let fmt = format,
              let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(file.length)) else {
            return []
        }
        do {
            try file.read(into: buffer)
        } catch {
            return []
        }
        guard let data = buffer.floatChannelData?[0] else { return [] }
        let frameCount = Int(buffer.frameLength)
        let samplesPerBucket = max(frameCount / count, 1)
        var result: [Float] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let start = i * samplesPerBucket
            let end   = min(start + samplesPerBucket, frameCount)
            guard start < frameCount else { result.append(0); continue }
            var peak: Float = 0
            for j in start..<end {
                peak = max(peak, abs(data[j]))
            }
            result.append(min(peak, 1.0))
        }
        return result
    }
}
