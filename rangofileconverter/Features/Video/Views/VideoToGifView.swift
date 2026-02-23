import SwiftUI
import AVFoundation

struct VideoToGifView: View {
    let thumbnail: UIImage
    let fileName: String
    let fileURL: URL
    let onConvert: (Int, Int) -> Void

    @State private var fps: Double = 10
    @State private var width: Double = 320

    // Preview state
    @State private var frames: [UIImage] = []
    @State private var currentFrameIndex = 0
    @State private var timer: Timer?
    @State private var isExtracting = false
    @State private var extractionTask: Task<Void, Never>?

    private var fileSize: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Max frames to extract for preview (keeps it snappy)
    private let maxPreviewFrames = 30

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Animated GIF preview
                    preview

                    // File info
                    VStack(spacing: 4) {
                        Text(fileName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(fileSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // FPS control
                    VStack(spacing: 8) {
                        HStack {
                            Text("Frame Rate")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(Int(fps)) FPS")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $fps, in: 5...30, step: 1)
                    }

                    // Width control
                    VStack(spacing: 8) {
                        HStack {
                            Text("Width")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(Int(width))px")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $width, in: 160...640, step: 20)
                    }

                    // Frame info
                    if !frames.isEmpty {
                        HStack {
                            Text("\(frames.count) frames")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "~%.1fs", Double(frames.count) / fps))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }

            // Convert button
            VStack {
                Button {
                    onConvert(Int(fps), Int(width))
                } label: {
                    Text("Create GIF")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }
            .padding(20)
            .background(.bar)
        }
        .navigationTitle("Convert GIF")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { extractFrames() }
        .onDisappear {
            stopTimer()
            extractionTask?.cancel()
        }
        .onChange(of: fps) { _ in restartTimer() }
        .onChange(of: width) { _ in extractFrames() }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            if frames.isEmpty {
                // Show static thumbnail while extracting
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        if isExtracting {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Generating preview...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
            } else {
                VStack(spacing: 8) {
                    Image(uiImage: frames[currentFrameIndex])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Frame \(currentFrameIndex + 1) of \(frames.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Frame Extraction

    private func extractFrames() {
        extractionTask?.cancel()
        stopTimer()
        isExtracting = true

        let targetWidth = Int(width)
        let targetFps = Int(fps)
        let url = fileURL
        let maxFrames = maxPreviewFrames

        extractionTask = Task.detached {
            let asset = AVAsset(url: url)
            guard let duration = try? await asset.load(.duration) else { return }
            let totalSeconds = CMTimeGetSeconds(duration)
            guard totalSeconds > 0 else { return }

            // Calculate how many frames to extract (cap at maxFrames, first 3 seconds max for preview)
            let previewDuration = min(totalSeconds, 3.0)
            let frameCount = min(Int(previewDuration * Double(targetFps)), maxFrames)
            guard frameCount > 0 else { return }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: targetWidth, height: targetWidth)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            var extracted: [UIImage] = []
            let interval = previewDuration / Double(frameCount)

            for i in 0..<frameCount {
                guard !Task.isCancelled else { return }
                let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    extracted.append(UIImage(cgImage: cgImage))
                }
            }

            guard !Task.isCancelled, !extracted.isEmpty else { return }

            await MainActor.run {
                frames = extracted
                currentFrameIndex = 0
                isExtracting = false
                startTimer()
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        guard !frames.isEmpty else { return }
        let interval = 1.0 / fps
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            currentFrameIndex = (currentFrameIndex + 1) % frames.count
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func restartTimer() {
        stopTimer()
        if !frames.isEmpty {
            startTimer()
        }
    }
}
