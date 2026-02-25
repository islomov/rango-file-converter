import SwiftUI
import AVFoundation
import Combine

struct ExtractAudioDetailView: View {
    let thumbnail: UIImage
    let fileName: String
    let fileURL: URL
    let onExtract: (FormatDefinition) -> Void

    private static let supportedAudioFormats = FormatRegistry.audioFormats

    @State private var targetFormat: FormatDefinition = FormatRegistry.audioFormats[0] // MP3
    @State private var fileSizeText: String = ""
    @State private var audioPlayer: AVPlayer?
    @State private var isPlayingAudio = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    @State private var timeObserver: Any?
    @State private var durationTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                    Image(systemName: "music.note")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Audio playback
                HStack(spacing: 16) {
                    Button {
                        toggleAudioPlayback()
                    } label: {
                        Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 4) {
                        Slider(
                            value: $currentTime,
                            in: 0...max(duration, 1)
                        ) { editing in
                            isSeeking = editing
                            if !editing {
                                seekTo(currentTime)
                            }
                        }
                        .tint(.blue)

                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatTime(duration))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(fileName)
                        .font(.headline)
                    Text(fileSizeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Extract as")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(Self.supportedAudioFormats) { format in
                            Button(format.displayName) {
                                targetFormat = format
                            }
                            .buttonStyle(.bordered)
                            .tint(targetFormat.id == format.id ? .accentColor : .secondary)
                        }
                    }
                }

                Button {
                    onExtract(targetFormat)
                } label: {
                    Text("Extract Audio")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .navigationTitle("Extract Audio")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Audio Playback

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
}
