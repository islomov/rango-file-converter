import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct MakeGifView: View {
    let fileURLs: [URL]
    let fileNames: [String]
    let onApply: (Double, Bool) -> Void

    @State private var frameDelay: Double = 0.2
    @State private var loopForever = true
    @State private var currentFrameIndex = 0
    @State private var timer: Timer?
    @State private var previewFrames: [UIImage] = []

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            preview

            Spacer()

            controls
        }
        .navigationTitle("Make GIF")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPreviews()
            startTimer()
        }
        .onDisappear { stopTimer() }
        .onChange(of: frameDelay) { _ in
            restartTimer()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 12) {
            if currentFrameIndex < previewFrames.count {
                Image(uiImage: previewFrames[currentFrameIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ProgressView()
                    .frame(height: 350)
            }

            Text("Frame \(currentFrameIndex + 1) of \(fileURLs.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Text("Frame Delay")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(String(format: "%.2fs", frameDelay))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $frameDelay, in: 0.05...1.0, step: 0.05)
            }

            HStack {
                Text("Loop Forever")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Toggle("", isOn: $loopForever)
                    .labelsHidden()
            }

            HStack {
                Text("\(fileURLs.count) frames")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "~%.1fs total", Double(fileURLs.count) * frameDelay))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                stopTimer()
                onApply(frameDelay, loopForever)
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
