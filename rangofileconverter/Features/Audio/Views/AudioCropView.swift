import SwiftUI
import AVFoundation

struct AudioCropView: View {
    let fileURL: URL
    let fileName: String
    let onApply: (_ startTime: Double, _ endTime: Double) -> Void

    private static let playableExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "aiff", "flac", "caf", "au", "mp2"
    ]

    @Environment(\.dismiss) private var dismiss
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
            previewSection

            controlsSection

            Spacer(minLength: 0)

            bottomButton
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .task {
            await setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Crop audio")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            HStack {
                Spacer()
                Button {
                    cleanupPlayer()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(hex: "888888").opacity(0.08))
                        )
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "E6E6EC"))

                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(width: 40, height: 40)

                    Text(sourceExtension.uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .tracking(-0.408)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(hex: "888888").opacity(0.12))
                        )
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 16)

            if duration > 0 {
                Text(formatTime(currentTime))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "1D1D1D"))
                    .tracking(-0.408)
                    .monospacedDigit()
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 24) {
            // Playback controls
            if isConverting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Preparing audio...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "888888"))
                }
            } else if player != nil {
                HStack(spacing: 12) {
                    Button {
                        pauseAndSeek(to: startTime)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "1D1D1D"))
                            .frame(width: 32, height: 32)
                    }

                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(Color(hex: "F4800D"))
                    }

                    Button {
                        pauseAndSeek(to: max(startTime, endTime - 0.5))
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "1D1D1D"))
                            .frame(width: 32, height: 32)
                    }
                }
            }

            // Time info + slider
            VStack(spacing: 12) {
                HStack {
                    Text("Start: \(formatTime(startTime))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "888888"))
                        .tracking(-0.408)

                    Spacer()

                    Text("Clip length \(formatTime(max(endTime - startTime, 0)))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "888888"))
                        .tracking(-0.408)

                    Spacer()

                    Text("End: \(formatTime(endTime))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "888888"))
                        .tracking(-0.408)
                }
                .monospacedDigit()

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
            }
        }
        .padding(16)
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Button {
                player?.pause()
                isPlaying = false
                onApply(startTime, endTime)
            } label: {
                Text("Clip audio")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(endTime - startTime < 0.1)
            .opacity(endTime - startTime < 0.1 ? 0.5 : 1)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Player

    private var isAVPlayerCompatible: Bool {
        Self.playableExtensions.contains(sourceExtension.lowercased())
    }

    private func setupPlayer() async {
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
