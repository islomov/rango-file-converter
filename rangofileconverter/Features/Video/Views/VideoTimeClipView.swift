import SwiftUI
import AVFoundation

struct VideoTimeClipView: View {
    let videoURL: URL
    let thumbnail: UIImage
    let fileName: String
    let onApply: (_ startTime: Double, _ endTime: Double) -> Void

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
            Spacer()
            videoPreview
            Spacer()
            controls
        }
        .navigationTitle("Time Clip")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    // MARK: - Video Preview

    private var videoPreview: some View {
        VStack(spacing: 12) {
            ZStack {
                if let player {
                    PlayerView(player: player)
                        .aspectRatio(videoAspectRatio ?? (thumbnail.size.width / thumbnail.size.height), contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { togglePlayback() }
                        .overlay {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(.black.opacity(0.4), in: Circle())
                                .opacity(isPlaying ? 0 : 1)
                                .animation(.easeInOut(duration: 0.2), value: isPlaying)
                        }
                } else {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                }
            }
            .frame(maxHeight: 400)

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

            Button {
                player?.pause()
                isPlaying = false
                onApply(startTime, endTime)
            } label: {
                Text("Clip Video")
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

// MARK: - Range Slider

private struct RangeSliderView: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let bounds: ClosedRange<Double>
    var onLowerChanged: () -> Void = {}
    var onUpperChanged: () -> Void = {}

    @State private var isDraggingLower = false
    @State private var isDraggingUpper = false

    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - thumbSize
            let range = bounds.upperBound - bounds.lowerBound

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                let lowerFraction = range > 0 ? (lowerValue - bounds.lowerBound) / range : 0
                let upperFraction = range > 0 ? (upperValue - bounds.lowerBound) / range : 1
                Capsule()
                    .fill(.mint)
                    .frame(
                        width: CGFloat(upperFraction - lowerFraction) * width,
                        height: trackHeight
                    )
                    .offset(x: thumbSize / 2 + CGFloat(lowerFraction) * width)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(Circle().stroke(.mint, lineWidth: 2))
                    .offset(x: CGFloat(lowerFraction) * width)
                    .gesture(
                        DragGesture()
                            .onChanged { drag in
                                isDraggingLower = true
                                let fraction = max(0, min(Double(drag.location.x / width), Double(upperValue - bounds.lowerBound) / range - 0.01))
                                lowerValue = bounds.lowerBound + fraction * range
                                onLowerChanged()
                            }
                            .onEnded { _ in isDraggingLower = false }
                    )

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(Circle().stroke(.mint, lineWidth: 2))
                    .offset(x: CGFloat(upperFraction) * width)
                    .gesture(
                        DragGesture()
                            .onChanged { drag in
                                isDraggingUpper = true
                                let fraction = min(1, max(Double(drag.location.x / width), Double(lowerValue - bounds.lowerBound) / range + 0.01))
                                upperValue = bounds.lowerBound + fraction * range
                                onUpperChanged()
                            }
                            .onEnded { _ in isDraggingUpper = false }
                    )
            }
        }
        .frame(height: thumbSize)
    }
}
