import SwiftUI
import AVFoundation
import AVKit

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
    let onApply: (UIImage, URL) async -> Void

    @State private var selectedSpeed: SpeedPreset = .double
    @State private var isApplying = false
    @State private var originalDuration: Double = 0
    @State private var player: AVPlayer?
    @State private var videoAspectRatio: CGFloat?
    @State private var isLoaded = false
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                preview
                Spacer()
                controls
            }
            .allowsHitTesting(!isApplying)

            if isApplying {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Changing speed...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationTitle("Speed Change")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    selectedSpeed = .double
                }
                .disabled(isApplying)
            }
        }
        .onAppear {
            startLoading()
        }
        .onDisappear {
            tearDownPlayer()
        }
        .onChange(of: selectedSpeed) {
            restartWithSpeed()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 16) {
            ZStack {
                // Always show thumbnail as base layer to prevent flicker
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let player, isLoaded {
                    VideoPlayer(player: player)
                        .aspectRatio(videoAspectRatio ?? (thumbnail.size.width / thumbnail.size.height), contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity)
                }

                if !isLoaded {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                }
            }
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

            Button {
                isApplying = true
                player?.pause()
                Task {
                    if let outputURL = await applySpeedChange() {
                        await onApply(thumbnail, outputURL)
                    }
                    isApplying = false
                }
            } label: {
                if isApplying {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Apply")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isApplying || !isLoaded)
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

    // MARK: - Player Lifecycle

    private func startLoading() {
        // Cancel any previous load if view re-appears
        loadTask?.cancel()
        tearDownPlayer()

        // Delay to let the navigation animation finish (~0.4s)
        loadTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            await loadVideoMetadata()
            guard !Task.isCancelled else { return }

            let item = AVPlayerItem(url: fileURL)
            let avPlayer = AVPlayer(playerItem: item)
            avPlayer.actionAtItemEnd = .pause
            player = avPlayer

            withAnimation(.easeIn(duration: 0.2)) {
                isLoaded = true
            }

            restartWithSpeed()
        }
    }

    private func tearDownPlayer() {
        loadTask?.cancel()
        loadTask = nil

        if let player {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        player = nil
        isLoaded = false
        originalDuration = 0
        videoAspectRatio = nil
    }

    private func loadVideoMetadata() async {
        let asset = AVURLAsset(url: fileURL)

        async let durationLoad = asset.load(.duration)
        async let tracksLoad = asset.loadTracks(withMediaType: .video)

        if let duration = try? await durationLoad {
            let seconds = CMTimeGetSeconds(duration)
            await MainActor.run {
                originalDuration = seconds
            }
        }

        if let track = try? await tracksLoad.first,
           let size = try? await track.load(.naturalSize),
           let transform = try? await track.load(.preferredTransform) {
            let transformed = size.applying(transform)
            let w = abs(transformed.width)
            let h = abs(transformed.height)
            if w > 0 && h > 0 {
                await MainActor.run {
                    videoAspectRatio = w / h
                }
            }
        }
    }

    private func restartWithSpeed() {
        guard let player, isLoaded else { return }
        player.pause()
        player.seek(to: .zero)
        player.rate = Float(selectedSpeed.rawValue)
    }

    // MARK: - Processing

    private func applySpeedChange() async -> URL? {
        let ext = fileURL.pathExtension.lowercased()
        let outputExt = (ext.isEmpty || ext == "mov") ? "mp4" : ext
        let outputName = "speed_\(UUID().uuidString.prefix(8)).\(outputExt)"
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
        let outputURL = outputDir.appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let speed = selectedSpeed.rawValue
        let videoFilter = "setpts=PTS/\(speed)"
        let audioFilter = buildAtempoFilter(for: speed)

        let extraArgs = ["-filter:v", videoFilter, "-filter:a", audioFilter]

        do {
            try await FFmpegWrapper.shared.convert(
                input: fileURL,
                output: outputURL,
                extraArgs: extraArgs
            )
            return outputURL
        } catch {
            print("[VideoSpeed] FFmpeg error: \(error)")
            return nil
        }
    }

    /// Build chained atempo filters for the given speed.
    /// FFmpeg's atempo only accepts values in [0.5, 2.0], so we chain multiple filters.
    private func buildAtempoFilter(for speed: Double) -> String {
        var remaining = speed
        var filters: [String] = []

        while remaining > 2.0 {
            filters.append("atempo=2.0")
            remaining /= 2.0
        }
        while remaining < 0.5 {
            filters.append("atempo=0.5")
            remaining /= 0.5
        }

        if abs(remaining - 1.0) > 0.001 {
            filters.append("atempo=\(remaining)")
        }

        return filters.isEmpty ? "atempo=1.0" : filters.joined(separator: ",")
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
