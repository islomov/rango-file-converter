import SwiftUI
import AVFoundation

struct AudioCropView: View {
    let fileURL: URL
    let fileName: String
    let onApply: (_ startTime: Double, _ endTime: Double) -> Void

    private static let playableExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "aiff", "flac", "caf", "au", "mp2"
    ]

    @State private var duration: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var playableURL: URL?
    @State private var isConverting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            audioPreview
            Spacer()
            controls
        }
        .navigationTitle("Audio Cropping")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    // MARK: - Audio Preview

    private var audioPreview: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(height: 200)

                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text(sourceExtension.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.secondary, in: Capsule())
                }
            }

            HStack(spacing: 4) {
                Text(fileName)
                    .lineLimit(1)
                if duration > 0 {
                    Text("·")
                    Text(formatTime(currentTime))
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Duration")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(formatTime(duration))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                RangeSliderView(
                    lowerValue: $startTime,
                    upperValue: $endTime,
                    bounds: 0...max(duration, 0.01),
                    onLowerChanged: {
                        pauseAndSeek(to: startTime)
                    },
                    onUpperChanged: {
                        pauseAndSeek(to: max(startTime, endTime - 0.5))
                    }
                )

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatTime(startTime))
                            .font(.subheadline.monospacedDigit())
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Clip Length")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatTime(max(endTime - startTime, 0)))
                            .font(.subheadline.monospacedDigit().weight(.medium))
                            .foregroundStyle(.mint)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("End")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatTime(endTime))
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }

            // Playback controls
            if isConverting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Preparing audio...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if player != nil {
                HStack(spacing: 24) {
                    Button {
                        pauseAndSeek(to: startTime)
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.title3)
                    }

                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                    }

                    Button {
                        pauseAndSeek(to: max(startTime, endTime - 0.5))
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title3)
                    }
                }
                .foregroundStyle(.primary)
            }

            Button {
                player?.pause()
                isPlaying = false
                onApply(startTime, endTime)
            } label: {
                Text("Crop Audio")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
            .disabled(endTime - startTime < 0.1)
        }
        .padding(20)
        .background(.bar)
    }

    // MARK: - Player

    private var isAVPlayerCompatible: Bool {
        Self.playableExtensions.contains(sourceExtension.lowercased())
    }

    private func setupPlayer() async {
        // For non-compatible formats, convert to WAV for preview playback
        var audioURL = fileURL
        if !isAVPlayerCompatible {
            isConverting = true
            do {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_audio_preview", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let shortID = UUID().uuidString.prefix(8)
                let wavURL = tempDir.appendingPathComponent("preview_\(shortID).wav")
                try await FFmpegWrapper.shared.convert(
                    input: fileURL,
                    output: wavURL,
                    extraArgs: ["-vn", "-acodec", "pcm_s16le"]
                )
                audioURL = wavURL
                playableURL = wavURL
            } catch {
                // If conversion fails, just load duration without playback
                isConverting = false
                let asset = AVAsset(url: fileURL)
                if let cmDuration = try? await asset.load(.duration) {
                    let seconds = CMTimeGetSeconds(cmDuration)
                    if seconds.isFinite && seconds > 0 {
                        duration = seconds
                        endTime = seconds
                    }
                }
                return
            }
            isConverting = false
        }

        let asset = AVAsset(url: audioURL)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite && seconds > 0 {
                duration = seconds
                endTime = seconds
            }
        } catch {
            return
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let playerItem = AVPlayerItem(url: audioURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.actionAtItemEnd = .pause

        let observer = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak avPlayer] time in
            let secs = CMTimeGetSeconds(time)
            guard secs.isFinite else { return }
            currentTime = secs

            if isPlaying && secs >= endTime {
                avPlayer?.pause()
                isPlaying = false
                avPlayer?.seek(to: CMTime(seconds: startTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                currentTime = startTime
            }
        }

        timeObserver = observer
        player = avPlayer
    }

    private func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
                player?.play()
                isPlaying = true
            }
        }
    }

    private func pauseAndSeek(to seconds: Double) {
        player?.pause()
        isPlaying = false
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
    }

    private func cleanupPlayer() {
        player?.pause()
        isPlaying = false
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player = nil
        if let tempURL = playableURL {
            try? FileManager.default.removeItem(at: tempURL)
            playableURL = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Helpers

    private var sourceExtension: String {
        fileName.components(separatedBy: ".").last ?? ""
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
