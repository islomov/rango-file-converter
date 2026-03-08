import SwiftUI
import AVFoundation
import Combine

private enum AudioSpeedPreset: Double, CaseIterable {
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

struct AudioSpeedDetailView: View {
    let fileName: String
    let fileURL: URL
    let onConvert: (Double, FormatDefinition) -> Void

    private static let majorFormatNames: Set<String> = ["MP3", "WAV", "FLAC", "M4A", "AAC", "OGG", "AC3", "WMA"]
    private static let supportedAudioFormats = FormatRegistry.audioFormats.filter { majorFormatNames.contains($0.displayName) }
    private static let playableExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "aiff", "flac", "caf", "au", "mp2"
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpeed: AudioSpeedPreset = .quarter
    @State private var targetFormat: FormatDefinition = FormatRegistry.audioFormats[0]
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false
    @State private var duration: Double = 0
    @State private var timeObserver: Any?
    @State private var durationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            ScrollView {
                controlsSection
            }

            bottomButton
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .task { await setupPlayer() }
        .onDisappear { cleanupPlayer() }
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

                    VStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "888888"))

                        Text(sourceExtension.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "888888"))
                            )
                    }
                }
                .frame(width: 200)

                if duration > 0 {
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
            Text(formatDuration(duration))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))

            Text(formatDuration(duration / selectedSpeed.rawValue))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "F4800D"))
                .tracking(-0.408)
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 24) {
            playbackControls

            VStack(alignment: .leading, spacing: 8) {
                Text("Speed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "888888"))
                    .tracking(-0.408)

                speedPicker
            }

            formatSelection
        }
        .padding(16)
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                audioPlayer?.pause()
                isPlaying = false
                audioPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
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
                audioPlayer?.pause()
                isPlaying = false
                if let item = audioPlayer?.currentItem {
                    let total = item.duration.seconds
                    if total.isFinite {
                        audioPlayer?.seek(
                            to: CMTime(seconds: max(0, total - 0.5), preferredTimescale: 600),
                            toleranceBefore: .zero,
                            toleranceAfter: .zero
                        )
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

    private var speedPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AudioSpeedPreset.allCases, id: \.self) { preset in
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

    // MARK: - Format Selection

    private var formatSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Convert to")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "888888"))
                .tracking(-0.408)

            formatGrid
        }
    }

    private var formatGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Self.supportedAudioFormats) { format in
                formatButton(format)
            }
        }
    }

    private func formatButton(_ format: FormatDefinition) -> some View {
        let isSelected = targetFormat.id == format.id
        return Button {
            targetFormat = format
        } label: {
            Text(format.displayName)
                .font(.system(size: 16, weight: .semibold))
                .tracking(-0.408)
                .foregroundColor(
                    isSelected
                        ? Color(hex: "F4800D")
                        : Color(hex: "1D1D1D")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected
                                ? Color(hex: "F4800D").opacity(0.08)
                                : Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "888888").opacity(0.12))
                .frame(height: 1)

            VStack {
                Button {
                    cleanupPlayer()
                    onConvert(selectedSpeed.rawValue, targetFormat)
                } label: {
                    Text("Change speed")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.white)
    }

    // MARK: - Audio Playback

    private func setupPlayer() async {
        guard isAVPlayerCompatible else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let asset = AVAsset(url: fileURL)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite && seconds > 0 {
                duration = seconds
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
            if isPlaying && avPlayer.currentItem?.duration.seconds ?? 0 > 0 {
                let current = CMTimeGetSeconds(time)
                let total = avPlayer.currentItem?.duration.seconds ?? 0
                if current.isFinite && total.isFinite && current >= total - 0.1 {
                    isPlaying = false
                }
            }
        }

        timeObserver = observer
        audioPlayer = avPlayer
    }

    private func restartWithSpeed() {
        guard let audioPlayer else { return }
        audioPlayer.pause()
        isPlaying = false
        audioPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak audioPlayer] _ in
            audioPlayer?.rate = Float(selectedSpeed.rawValue)
            isPlaying = true
        }
    }

    private func togglePlayback() {
        guard let audioPlayer else { return }

        if isPlaying {
            audioPlayer.pause()
            isPlaying = false
        } else {
            let current = CMTimeGetSeconds(audioPlayer.currentTime())
            let total = audioPlayer.currentItem?.duration.seconds ?? 0
            if current.isFinite && total.isFinite && current >= total - 0.2 {
                audioPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak audioPlayer] _ in
                    audioPlayer?.rate = Float(selectedSpeed.rawValue)
                    isPlaying = true
                }
            } else {
                audioPlayer.rate = Float(selectedSpeed.rawValue)
                isPlaying = true
            }
        }
    }

    private func cleanupPlayer() {
        durationTask?.cancel()
        durationTask = nil
        audioPlayer?.pause()
        isPlaying = false
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private var isAVPlayerCompatible: Bool {
        Self.playableExtensions.contains(sourceExtension.lowercased())
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var sourceExtension: String {
        fileName.components(separatedBy: ".").last ?? ""
    }
}
