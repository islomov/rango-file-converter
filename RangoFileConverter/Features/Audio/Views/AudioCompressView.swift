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

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBitrate: AudioBitrate = .k192
    @State private var selectedSampleRate: AudioSampleRate = .hz44100
    @State private var selectedFormat: CompressOutputFormat = .mp3
    @State private var originalSize: Int64 = 0
    @State private var estimatedSize: Int64 = 0
    @State private var estimationTask: Task<Void, Never>?

    // Audio metadata for estimation
    @State private var audioDuration: Double = 0
    @State private var audioChannels: Int = 2
    @State private var originalSampleRate: Int = 44100

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
            previewSection

            ScrollView {
                controlsSection
            }

            Spacer(minLength: 0)

            bottomButton
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .onAppear {
            loadOriginalSize()
            loadAudioMetadata()
        }
        .onChange(of: selectedFormat) { _ in updateEstimatedSize() }
        .onChange(of: selectedBitrate) { _ in updateEstimatedSize() }
        .onChange(of: selectedSampleRate) { _ in updateEstimatedSize() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === audioPlayer?.currentItem else { return }
            isPlaying = false
            currentTime = duration
        }
        .onDisappear { cleanupPlayer() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Convert audio")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(AppColors.textSecondary.opacity(0.08))
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
                    .fill(AppColors.placeholder)
                    .frame(height: 180)

                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(sourceExtension.uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            AppColors.textSecondary.opacity(0.12),
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, 16)

            fileSizeInfo
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isAVPlayerCompatible {
                playbackControls
            }

            // Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                chipPicker(
                    items: CompressOutputFormat.allCases,
                    selected: selectedFormat,
                    label: \.rawValue
                ) { selectedFormat = $0 }
            }

            // Bitrate (hidden for lossless)
            if !selectedFormat.isLossless {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bitrate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)

                    chipPicker(
                        items: AudioBitrate.allCases,
                        selected: selectedBitrate,
                        label: \.label
                    ) { selectedBitrate = $0 }
                }
            }

            // Sample rate
            VStack(alignment: .leading, spacing: 8) {
                Text("Sample rate")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                chipPicker(
                    items: AudioSampleRate.allCases,
                    selected: selectedSampleRate,
                    label: \.label
                ) { selectedSampleRate = $0 }
            }
        }
        .padding(16)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(AppColors.accent)
                    .clipShape(Circle())
            }

            Text(formatTime(currentTime))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(-0.408)
                .monospacedDigit()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.accent.opacity(0.2))
                        .frame(height: 4)

                    Capsule()
                        .fill(AppColors.accent)
                        .frame(width: max(0, progress * geo.size.width), height: 4)

                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .fill(AppColors.surface)
                                .frame(width: 6, height: 6)
                        )
                        .offset(x: max(0, progress * geo.size.width - 8))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isSeeking = true
                            let fraction = min(max(value.location.x / geo.size.width, 0), 1)
                            currentTime = fraction * max(duration, 1)
                        }
                        .onEnded { _ in
                            isSeeking = false
                            seekTo(currentTime)
                        }
                )
            }
            .frame(height: 20)

            Text(formatTime(duration))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(-0.408)
                .monospacedDigit()
        }
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
                        Text(LocalizedStringKey(item[keyPath: label]))
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.408)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selected == item
                                    ? AppColors.accent
                                    : AppColors.textSecondary.opacity(0.08),
                                in: Capsule()
                            )
                            .foregroundColor(selected == item ? .white : AppColors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Button {
                onCompress(
                    selectedBitrate.rawValue,
                    selectedSampleRate.value,
                    selectedFormat.fileExtension
                )
            } label: {
                Text("Compress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Audio Playback Helpers

    private var isAVPlayerCompatible: Bool {
        Self.playableExtensions.contains(sourceExtension.lowercased())
    }

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
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

    // MARK: - File Size Info

    private var fileSizeInfo: some View {
        HStack(spacing: 4) {
            Text(formatBytes(originalSize))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            if estimatedSize > 0 {
                Image(systemName: "arrow.forward")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textPrimary)

                Text(formatBytes(estimatedSize))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(-0.408)

                if originalSize > 0 {
                    let ratio = Double(estimatedSize) / Double(originalSize) * 100
                    Text(String(format: "(%.0f%%)", ratio))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }
            }
        }
    }

    // MARK: - Audio Metadata & Estimation

    private func loadAudioMetadata() {
        let asset = AVURLAsset(url: fileURL)
        Task {
            if let dur = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(dur)
                if seconds.isFinite && seconds > 0 {
                    await MainActor.run {
                        audioDuration = seconds
                        duration = seconds
                        updateEstimatedSize()
                    }
                }
            }
            if let tracks = try? await asset.loadTracks(withMediaType: .audio),
               let track = tracks.first {
                let descriptions = try? await track.load(.formatDescriptions)
                if let desc = descriptions?.first {
                    let basicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
                    await MainActor.run {
                        if let basic = basicDesc?.pointee {
                            audioChannels = max(Int(basic.mChannelsPerFrame), 1)
                            if basic.mSampleRate > 0 {
                                originalSampleRate = Int(basic.mSampleRate)
                            }
                        }
                        updateEstimatedSize()
                    }
                }
            }
        }
    }

    private func updateEstimatedSize() {
        estimationTask?.cancel()
        estimationTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            let estimated = estimateCompressedSize()
            await MainActor.run {
                estimatedSize = estimated
            }
        }
    }

    private func estimateCompressedSize() -> Int64 {
        guard audioDuration > 0 else { return 0 }

        let sampleRate = Double(selectedSampleRate.value ?? originalSampleRate)

        if selectedFormat.isLossless {
            let bytesPerSample: Double = 2 // 16-bit PCM
            let channels = Double(audioChannels)
            let rawSize = sampleRate * bytesPerSample * channels * audioDuration

            switch selectedFormat {
            case .wav:
                return Int64(rawSize) + 44 // WAV header overhead
            case .flac:
                return Int64(rawSize * 0.6) // FLAC typically ~60% of raw
            default:
                return Int64(rawSize)
            }
        } else {
            // CBR estimation: bitrate (kbps) → bytes/sec = bitrate * 1000 / 8
            let bitrateBytes = Double(selectedBitrate.rawValue) * 1000.0 / 8.0
            let estimated = bitrateBytes * audioDuration
            // Add ~5% for container/header overhead
            return Int64(estimated * 1.05)
        }
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
        if bytes == 0 { return "\u{2014}" }
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
