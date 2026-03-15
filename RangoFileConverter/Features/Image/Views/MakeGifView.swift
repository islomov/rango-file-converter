import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct MakeGifView: View {
    let fileURLs: [URL]
    let fileNames: [String]
    let onApply: (Double, Bool, CGFloat) -> Void

    @State private var frameDelay: Double = 0.50
    @State private var loopForever = true
    @State private var gifWidth: Double = 800
    @State private var currentFrameIndex = 0
    @State private var timer: Timer?
    @State private var previewFrames: [UIImage] = []
    @Environment(\.dismiss) private var dismiss

    private var totalDuration: Double {
        Double(fileURLs.count) * frameDelay
    }

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            controlsSection

            Spacer(minLength: 0)

            bottomSection
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .onAppear {
            loadPreviews()
            startTimer()
        }
        .onDisappear { stopTimer() }
        .onChange(of: frameDelay) { _ in
            restartTimer()
        }
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
                    stopTimer()
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

            if currentFrameIndex < previewFrames.count {
                Image(uiImage: previewFrames[currentFrameIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                ProgressView()
                    .frame(height: 260)
                    .padding(.vertical, 24)
            }

            Text("\(currentFrameIndex + 1) of \(fileURLs.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)
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
        VStack(spacing: 16) {
            // Frame Delay slider
            VStack(spacing: 12) {
                HStack {
                    Text("Frame Delay")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                    Spacer()
                    Text(String(format: "%.2fs", frameDelay))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }

                Slider(value: $frameDelay, in: 0.05...1.0, step: 0.05)
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
                    Text("\(Int(gifWidth))px")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }

                Slider(value: $gifWidth, in: 160...800, step: 40)
                    .tint(AppColors.accent)
            }

            // Loop Forever toggle
            HStack {
                Text("Loop Forever")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-0.408)
                Spacer()
                Toggle("", isOn: $loopForever)
                    .labelsHidden()
                    .tint(AppColors.accent)
            }
            .padding(16)
            .background(AppColors.textSecondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(16)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 10) {
            // Frame info
            HStack {
                Text("\(fileURLs.count) frames")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)
                Spacer()
                Text(String(format: "%.1fs total", totalDuration))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)
            }

            // Create GIF button
            Button {
                stopTimer()
                onApply(frameDelay, loopForever, CGFloat(gifWidth))
            } label: {
                Text("Create GIF")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent],
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

    // MARK: - Preview Loading

    private func loadPreviews() {
        previewFrames = fileURLs.compactMap { url in
            ImageConverterViewModel.loadPreviewImage(from: url, maxPixelSize: 400)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        guard !fileURLs.isEmpty else { return }
        timer = Timer.scheduledTimer(withTimeInterval: frameDelay, repeats: true) { _ in
            let count = previewFrames.isEmpty ? fileURLs.count : previewFrames.count
            guard count > 0 else { return }
            currentFrameIndex = (currentFrameIndex + 1) % count
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func restartTimer() {
        stopTimer()
        startTimer()
    }
}
