import SwiftUI
import AVFoundation

private enum SpeedPreset: Double, CaseIterable {
    case quarter = 0.25
    case half = 0.5
    case threeQuarters = 0.75
    case oneAndHalf = 1.5
    case double = 2.0
    case triple = 3.0
    case quadruple = 4.0

    var label: String {
        switch self {
        case .quarter: return "0.25x"
        case .half: return "0.5x"
        case .threeQuarters: return "0.75x"
        case .oneAndHalf: return "1.5x"
        case .double: return "2x"
        case .triple: return "3x"
        case .quadruple: return "4x"
        }
    }
}

struct VideoSpeedView: View {
    let thumbnail: UIImage
    let fileName: String
    let fileURL: URL
    let onApply: (_ speed: Double) -> Void

    @State private var selectedSpeed: SpeedPreset = .double
    @State private var isPlaying = false
    @State private var originalDuration: Double = 0
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var videoAspectRatio: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            preview
            Spacer()
            controls
        }
        .navigationTitle("Speed Change")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    selectedSpeed = .double
                }
            }
        }
        .task {
            await setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: selectedSpeed) {
            restartWithSpeed()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 16) {
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
            .overlay(alignment: .topTrailing) {
                Text(selectedSpeed.label)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(8)
            }

            Text(fileName)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(.secondary)

            if originalDuration > 0 {
                HStack(spacing: 8) {
                    Text(formatDuration(originalDuration))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(formatDuration(originalDuration / selectedSpeed.rawValue))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Speed")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                speedPicker
            }

            // Playback controls
            HStack(spacing: 24) {
                Button {
                    player?.pause()
                    isPlaying = false
                    player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
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
                    player?.pause()
                    isPlaying = false
                    if let duration = player?.currentItem?.duration {
                        let end = CMTimeGetSeconds(duration)
                        if end.isFinite {
                            player?.seek(to: CMTime(seconds: max(0, end - 0.5), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                        }
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                }
            }
            .foregroundStyle(.primary)

            Button {
                player?.pause()
                isPlaying = false
                onApply(selectedSpeed.rawValue)
            } label: {
                Text("Apply")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(player == nil)
        }
        .padding(20)
        .background(.bar)
    }

    private var speedPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SpeedPreset.allCases, id: \.self) { preset in
                    Button {
                        selectedSpeed = preset
                    } label: {
                        Text(preset.label)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedSpeed == preset ? Color.orange : Color(.systemGray5),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedSpeed == preset ? .white : .primary)
                    }
                }
            }
        }
    }

    // MARK: - Player

    private func setupPlayer() async {
        let asset = AVAsset(url: fileURL)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite && seconds > 0 {
                originalDuration = seconds
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

        let playerItem = AVPlayerItem(url: fileURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.actionAtItemEnd = .pause

        let observer = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak avPlayer] time in
            guard let avPlayer else { return }
            // Detect when playback reaches the end
            if isPlaying && avPlayer.currentItem?.duration.seconds ?? 0 > 0 {
                let current = CMTimeGetSeconds(time)
                let total = avPlayer.currentItem?.duration.seconds ?? 0
                if current.isFinite && total.isFinite && current >= total - 0.1 {
                    isPlaying = false
                }
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
            // If at end, seek to beginning first
            let current = CMTimeGetSeconds(player.currentTime())
            let total = player.currentItem?.duration.seconds ?? 0
            if current.isFinite && total.isFinite && current >= total - 0.2 {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    player.rate = Float(selectedSpeed.rawValue)
                    isPlaying = true
                }
            } else {
                player.rate = Float(selectedSpeed.rawValue)
                isPlaying = true
            }
        }
    }

    private func restartWithSpeed() {
        guard let player else { return }
        player.pause()
        isPlaying = false
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            player.rate = Float(selectedSpeed.rawValue)
            isPlaying = true
        }
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

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
