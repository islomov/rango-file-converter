import SwiftUI
import AVFoundation

struct VideoToGifView: View {
    let thumbnail: UIImage
    let fileName: String
    let fileURL: URL
    let onConvert: (Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fps: Double = 10
    @State private var width: Double = 320

    // Preview state
    @State private var frames: [UIImage] = []
    @State private var currentFrameIndex = 0
    @State private var timer: Timer?
    @State private var isExtracting = false
    @State private var extractionTask: Task<Void, Never>?

    /// Max frames to extract for preview (keeps it snappy)
    private let maxPreviewFrames = 30

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            ScrollView {
                controlsSection
            }

            bottomButton
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .onAppear { extractFrames() }
        .onDisappear {
            stopTimer()
            extractionTask?.cancel()
        }
        .onChange(of: fps) { _ in restartTimer() }
        .onChange(of: width) { _ in extractFrames() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("GIF")
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

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.placeholder)
                        .aspectRatio(200.0 / 286.0, contentMode: .fit)
                        .frame(width: 200)

                    if frames.isEmpty {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                if isExtracting {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                    VStack(spacing: 8) {
                                        ProgressView()
                                        Text("Generating preview...")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppColors.textSecondary)
                                            .tracking(-0.408)
                                    }
                                }
                            }
                    } else {
                        Image(uiImage: frames[currentFrameIndex])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .frame(width: 200)

                if !frames.isEmpty {
                    Text("Frame \(currentFrameIndex + 1) of \(frames.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
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
        VStack(spacing: 24) {
            // Frame rate slider
            VStack(spacing: 12) {
                HStack {
                    Text("Frame rate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                    Spacer()
                    Text("\(Int(fps)) FPS")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }

                Slider(value: $fps, in: 5...30, step: 1)
                    .tint(AppColors.accent)
            }

            // Width slider
            VStack(spacing: 12) {
                HStack {
                    Text("Width")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                    Spacer()
                    Text("\(Int(width))px")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }

                Slider(value: $width, in: 160...640, step: 20)
                    .tint(AppColors.accent)
            }
        }
        .padding(16)
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack {
            Button {
                onConvert(Int(fps), Int(width))
            } label: {
                Text("Create GIF")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
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
                guard !Task.isCancelled else { return }
                frames = extracted
                currentFrameIndex = 0
                isExtracting = false
                startTimer()
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
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
