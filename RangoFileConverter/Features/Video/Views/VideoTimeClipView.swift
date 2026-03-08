import SwiftUI
import AVFoundation

struct VideoTimeClipView: View {
    let videoURL: URL
    let thumbnail: UIImage
    let fileName: String
    let onApply: (_ startTime: Double, _ endTime: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var duration: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var videoAspectRatio: CGFloat?

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
            Text("Time Clip")
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
                if let player {
                    PlayerView(player: player)
                        .aspectRatio(videoAspectRatio ?? (thumbnail.size.width / thumbnail.size.height), contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .contentShape(Rectangle())
                        .onTapGesture { togglePlayback() }
                } else {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(maxHeight: 286)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)

            if duration > 0 {
                Text(formatTime(currentTime))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "1D1D1D"))
                    .tracking(-0.408)
                    .monospacedDigit()
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

            // Time info + slider
            VStack(spacing: 12) {
                HStack {
                    Text("Start: \(formatTime(startTime))")
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

                Text("Clip length \(formatTime(max(endTime - startTime, 0)))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "888888"))
                    .tracking(-0.408)
                    .monospacedDigit()
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
                Text("Clip video")
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

    private func setupPlayer() async {
        let asset = AVAsset(url: videoURL)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite && seconds > 0 {
                duration = seconds
                endTime = seconds
            }

            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = tracks.first {
                let size = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let transformedSize = size.applying(transform)
                let w = abs(transformedSize.width)
                let h = abs(transformedSize.height)
                if w > 0 && h > 0 {
                    videoAspectRatio = w / h
                }
            }
        } catch {
            return
        }

        let playerItem = AVPlayerItem(url: videoURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.actionAtItemEnd = .pause

        let observer = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak avPlayer] time in
            let secs = CMTimeGetSeconds(time)
            guard secs.isFinite else { return }
            currentTime = secs

            // Stop at end boundary during playback
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
            // Always start from startTime
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
    }

    // MARK: - Helpers

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
