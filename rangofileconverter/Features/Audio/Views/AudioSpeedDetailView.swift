import SwiftUI
import AVFoundation
import Combine

struct AudioSpeedDetailView: View {
    let fileName: String
    let fileURL: URL
    let onConvert: (Double, FormatDefinition) -> Void

    private static let supportedAudioFormats = FormatRegistry.audioFormats
    private static let playableExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "aiff", "flac", "caf", "au", "mp2"
    ]

    private static let speedPresets: [(label: String, value: Double)] = [
        ("0.5x", 0.5), ("0.75x", 0.75), ("1.0x", 1.0),
        ("1.25x", 1.25), ("1.5x", 1.5), ("2.0x", 2.0)
    ]

    @State private var speed: Double = 1.0
    @State private var targetFormat: FormatDefinition = FormatRegistry.audioFormats[0]
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
                audioIcon
                if isAVPlayerCompatible { playbackSection }
                speedControl
                fileInfo
                formatSelection
                convertButton
            }
            .padding(20)
        }
        .navigationTitle("Audio Speed")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFileSize() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === audioPlayer?.currentItem else { return }
            isPlayingAudio = false
            currentTime = duration
        }
        .onDisappear { cleanupPlayer() }
    }

    // MARK: - Sections

    private var audioIcon: some View {
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
    }

    private var playbackSection: some View {
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

    private var speedControl: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Speed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2fx", speed))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }

            Slider(value: $speed, in: 0.25...4.0, step: 0.05)
                .tint(.blue)
                .onChange(of: speed) { newValue in
                    updatePlaybackRate(newValue)
                }

            speedPresetButtons
        }
    }

    private var speedPresetButtons: some View {
        HStack(spacing: 8) {
            ForEach(Self.speedPresets, id: \.value) { preset in
                speedPresetButton(label: preset.label, value: preset.value)
            }
        }
    }

    private func speedPresetButton(label: String, value: Double) -> some View {
        let isSelected = speed == value
        return Button(label) {
            speed = value
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .clipShape(Capsule())
    }

    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fileName)
                .font(.headline)
            Text(fileSizeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output format")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            formatGrid
        }
    }

    private var formatGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
            ForEach(Self.supportedAudioFormats) { format in
                formatButton(format)
            }
        }
    }

    private func formatButton(_ format: FormatDefinition) -> some View {
        Button(format.displayName) {
            targetFormat = format
        }
        .buttonStyle(.bordered)
        .tint(targetFormat.id == format.id ? .accentColor : .secondary)
    }

    private var convertButton: some View {
        Button {
            onConvert(speed, targetFormat)
        } label: {
            Text("Convert")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Helpers

    private func loadFileSize() async {
        let path = fileURL.path
        let size = await Task.detached(priority: .utility) {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let bytes = attrs[.size] as? Int64 else { return "" }
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }.value
        fileSizeText = size
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
            audioPlayer.rate = Float(speed)
        }
        isPlayingAudio.toggle()
    }

    private func updatePlaybackRate(_ newSpeed: Double) {
        guard let player = audioPlayer, isPlayingAudio else { return }
        player.rate = Float(newSpeed)
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
