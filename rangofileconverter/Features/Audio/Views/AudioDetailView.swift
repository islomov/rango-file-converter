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
                // Audio icon
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

                // Audio playback
                if isAVPlayerCompatible {
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
                }

                // File info
                VStack(alignment: .leading, spacing: 8) {
                    Text(fileName)
                        .font(.headline)
                    Text(fileSizeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Format selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Convert to")
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

                // Convert button
                Button {
                    onConvert(targetFormat)
                } label: {
                    Text("Convert")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .navigationTitle("Audio Conversion")
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
