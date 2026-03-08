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

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpeed: SpeedPreset = .double
    @State private var isPlaying = false
    @State private var originalDuration: Double = 0
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var videoAspectRatio: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            ScrollView {
                controlsSection
            }

            bottomButtons
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .task {
            await setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: selectedSpeed) { _ in
            restartWithSpeed()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Speed change")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            HStack {
                Spacer()
                Button {
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

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "E6E6EC"))
                        .aspectRatio(175.0 / 250.0, contentMode: .fit)
                        .frame(width: 200)

                    if let player {
                        PlayerView(player: player)
                            .aspectRatio(videoAspectRatio ?? (thumbnail.size.width / thumbnail.size.height), contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .frame(width: 200)

                if originalDuration > 0 {
                    durationInfo
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var durationInfo: some View {
        HStack(spacing: 4) {
            Text(formatDuration(originalDuration))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))

            Text(formatDuration(originalDuration / selectedSpeed.rawValue))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "F4800D"))
                .tracking(-0.408)
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Speed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "888888"))
                    .tracking(-0.408)

                speedPicker
            }

            playbackControls
        }
        .padding(16)
    }

    private var speedPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SpeedPreset.allCases, id: \.self) { preset in
                    Button {
                        selectedSpeed = preset
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.408)
                            .foregroundColor(
                                selectedSpeed == preset
                                    ? .white
                                    : Color(hex: "1D1D1D")
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        selectedSpeed == preset
                                            ? Color(hex: "F4800D")
                                            : Color(hex: "888888").opacity(0.08)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                player?.pause()
                isPlaying = false
                player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            } label: {
                Image("icon_play_back")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 32, height: 32)
                    .foregroundColor(Color(hex: "1D1D1D"))
            }

            Button {
                togglePlayback()
            } label: {
                if isPlaying {
                    Image(systemName: "pause.circle.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(
                            Color(hex: "F4800D"),
                            Color(hex: "F4800D").opacity(0.15)
                        )
                } else {
                    Image("icon_video_play")
                        .resizable()
                        .frame(width: 56, height: 56)
                }
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
                Image("icon_play_forward")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 32, height: 32)
                    .foregroundColor(Color(hex: "1D1D1D"))
            }
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let spacing: CGFloat = 12
            let resetWidth = (totalWidth - spacing) * 0.3
            let convertWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                Button {
                    selectedSpeed = .double
                } label: {
                    Text("Reset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .tracking(-0.408)
                        .frame(width: resetWidth, height: 60)
                        .background(Color(hex: "888888").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    player?.pause()
                    isPlaying = false
                    onApply(selectedSpeed.rawValue)
                } label: {
                    Text("Change speed")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: convertWidth, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(player == nil)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 60)
        .padding(.vertical, 24)
    }

    // MARK: - Player

    private func setupPlayer() async {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

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
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
                    player?.rate = Float(selectedSpeed.rawValue)
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
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
            player?.rate = Float(selectedSpeed.rawValue)
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
