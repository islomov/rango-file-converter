import SwiftUI
import AVFoundation
import Combine

struct AudioDetailView: View {
    let fileName: String
    let fileURL: URL
    let onConvert: (FormatDefinition) -> Void

    private static let supportedAudioFormats = FormatRegistry.audioFormats
    private static let playableExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "aiff", "flac", "caf", "au", "mp2"
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var targetFormat: FormatDefinition = FormatRegistry.audioFormats[0] // MP3
    @State private var fileSizeText: String = ""
    @State private var audioPlayer: AVPlayer?
    @State private var isPlayingAudio = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    @State private var timeObserver: Any?
    @State private var durationTask: Task<Void, Never>?

    private let formatColumns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            ScrollView {
                VStack(spacing: 12) {
                    if isAVPlayerCompatible {
                        audioPlayerSection
                    }

                    formatSelection
                }
            }

            bottomButton
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .task {
            let path = fileURL.path
            let size = await Task.detached(priority: .utility) {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let bytes = attrs[.size] as? Int64 else { return "" }
                return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }.value
            fileSizeText = size
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === audioPlayer?.currentItem else { return }
            isPlayingAudio = false
            currentTime = duration
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Convert audio")
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

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "E6E6EC"))
                    .frame(height: 180)

                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(Color(hex: "1D1D1D"))

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
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Audio Player

    private var audioPlayerSection: some View {
        HStack(spacing: 12) {
            Button {
                toggleAudioPlayback()
            } label: {
                Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(hex: "F4800D"))
            }

            Text(formatTime(currentTime))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "888888"))
                .tracking(-0.408)

            VStack(spacing: 0) {
                Slider(
                    value: $currentTime,
                    in: 0...max(duration, 1)
                ) { editing in
                    isSeeking = editing
                    if !editing {
                        seekTo(currentTime)
                    }
                }
                .tint(Color(hex: "F4800D"))
            }

            Text(formatTime(duration))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "888888"))
                .tracking(-0.408)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Format Selection

    private var formatSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Convert to")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "888888"))
                .tracking(-0.408)

            LazyVGrid(columns: formatColumns, spacing: 4) {
                ForEach(Self.supportedAudioFormats) { format in
                    Button {
                        targetFormat = format
                    } label: {
                        Text(format.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(-0.408)
                            .foregroundColor(
                                targetFormat.id == format.id
                                    ? Color(hex: "F4800D")
                                    : Color(hex: "1D1D1D")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        targetFormat.id == format.id
                                            ? Color(hex: "F4800D").opacity(0.08)
                                            : Color.clear
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Button {
            onConvert(targetFormat)
        } label: {
            Text("Convert")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }

    // MARK: - Audio Playback

    private var isAVPlayerCompatible: Bool {
        Self.playableExtensions.contains(sourceExtension.lowercased())
    }

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func toggleAudioPlayback() {
        activateAudioSession()
        if audioPlayer == nil {
            let player = AVPlayer(url: fileURL)
            audioPlayer = player
            setupTimeObserver(player: player)
            loadDuration(player: player)
        }
        guard let audioPlayer = audioPlayer else { return }

        if isPlayingAudio {
            audioPlayer.pause()
        } else {
            if let currentItem = audioPlayer.currentItem,
               currentItem.duration.isValid,
               CMTimeCompare(audioPlayer.currentTime(), currentItem.duration) >= 0 {
                audioPlayer.seek(to: .zero)
                currentTime = 0
            }
            audioPlayer.play()
        }
        isPlayingAudio.toggle()
    }

    private func setupTimeObserver(player: AVPlayer) {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard player != nil, !isSeeking else { return }
            currentTime = CMTimeGetSeconds(time)
        }
    }

    private func loadDuration(player: AVPlayer) {
        durationTask?.cancel()
        durationTask = Task {
            guard let item = player.currentItem else { return }
            if let dur = try? await item.asset.load(.duration) {
                guard !Task.isCancelled else { return }
                let seconds = CMTimeGetSeconds(dur)
                if seconds.isFinite && seconds > 0 {
                    await MainActor.run { duration = seconds }
                }
            }
        }
    }

    private func seekTo(_ time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        audioPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func cleanupPlayer() {
        durationTask?.cancel()
        durationTask = nil
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        audioPlayer?.pause()
        audioPlayer?.replaceCurrentItem(with: nil)
        audioPlayer = nil
        isPlayingAudio = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var sourceExtension: String {
        fileName.components(separatedBy: ".").last ?? ""
    }
}
