import SwiftUI
import AVFoundation

private enum AudioBitrate: Int, CaseIterable {
    case k64 = 64
    case k128 = 128
    case k192 = 192
    case k256 = 256
    case k320 = 320

    var label: String { "\(rawValue) kbps" }
}

private enum AudioSampleRate: String, CaseIterable {
    case original = "Original"
    case hz48000 = "48000"
    case hz44100 = "44100"
    case hz22050 = "22050"

    var label: String {
        self == .original ? rawValue : "\(rawValue) Hz"
    }

    var value: Int? {
        switch self {
        case .original: return nil
        case .hz48000: return 48000
        case .hz44100: return 44100
        case .hz22050: return 22050
        }
    }
}

private enum CompressOutputFormat: String, CaseIterable {
    case mp3 = "MP3"
    case aac = "AAC"
    case ogg = "OGG"
    case opus = "OPUS"
    case m4a = "M4A"
    case flac = "FLAC"
    case wav = "WAV"

    var fileExtension: String { rawValue.lowercased() }

    var isLossless: Bool {
        self == .flac || self == .wav
    }
}

struct AudioCompressView: View {
    let fileName: String
    let fileURL: URL
    let onCompress: (_ bitrate: Int, _ sampleRate: Int?, _ format: String) -> Void

    private static let playableExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "aiff", "flac", "caf", "au", "mp2"
    ]

    @State private var selectedBitrate: AudioBitrate = .k128
    @State private var selectedSampleRate: AudioSampleRate = .original
    @State private var selectedFormat: CompressOutputFormat = .mp3
    @State private var originalSize: Int64 = 0

    // Playback state
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    @State private var timeObserver: Any?
    @State private var durationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    preview
                    if isAVPlayerCompatible {
                        playbackControls
                    }
                }
                .padding(20)
            }
            controls
        }
        .navigationTitle("Compress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadOriginalSize() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === audioPlayer?.currentItem else { return }
            isPlaying = false
            currentTime = duration
        }
        .onDisappear { cleanupPlayer() }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(height: 160)

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

            Text(formatBytes(originalSize))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(fileName)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Playback

    private var playbackControls: some View {
        HStack(spacing: 16) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
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

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            // Output format
            VStack(spacing: 8) {
                Text("Format")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                chipPicker(
                    items: CompressOutputFormat.allCases,
                    selected: selectedFormat,
                    label: \.rawValue
                ) { selectedFormat = $0 }
            }

            // Bitrate (hidden for lossless)
            if !selectedFormat.isLossless {
                VStack(spacing: 8) {
                    Text("Bitrate")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    chipPicker(
                        items: AudioBitrate.allCases,
                        selected: selectedBitrate,
                        label: \.label
                    ) { selectedBitrate = $0 }
                }
            }

            // Sample rate
            VStack(spacing: 8) {
                Text("Sample Rate")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                chipPicker(
                    items: AudioSampleRate.allCases,
                    selected: selectedSampleRate,
                    label: \.label
                ) { selectedSampleRate = $0 }
            }

            // Compress button
            Button {
                onCompress(
                    selectedBitrate.rawValue,
                    selectedSampleRate.value,
                    selectedFormat.fileExtension
                )
            } label: {
                Text("Compress")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(20)
        .background(.bar)
    }

    // MARK: - Chip Picker

    private func chipPicker<T: Hashable>(
        items: [T],
        selected: T,
        label: KeyPath<T, String>,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item[keyPath: label])
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selected == item ? Color.purple : Color(.systemGray5),
                                in: Capsule()
                            )
                            .foregroundStyle(selected == item ? .white : .primary)
                    }
                }
            }
        }
    }

    // MARK: - Audio Playback Helpers

    private var isAVPlayerCompatible: Bool {
        Self.playableExtensions.contains(sourceExtension.lowercased())
    }

    private func togglePlayback() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        if audioPlayer == nil {
            let player = AVPlayer(url: fileURL)
            audioPlayer = player
            setupTimeObserver(player: player)
            loadDuration(player: player)
        }
        guard let audioPlayer = audioPlayer else { return }

        if isPlaying {
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
        isPlaying.toggle()
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
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Helpers

    private var sourceExtension: String {
        fileName.components(separatedBy: ".").last ?? ""
    }

    private func loadOriginalSize() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64 {
            originalSize = size
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
