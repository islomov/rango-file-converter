import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct MakeGifView: View {
    let images: [UIImage]
    let fileNames: [String]
    let onApply: (UIImage, URL) async -> Void

    @State private var frameDelay: Double = 0.2
    @State private var loopForever = true
    @State private var isApplying = false
    @State private var currentFrameIndex = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                // Preview
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
                    Text("Creating GIF...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationTitle("Make GIF")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onChange(of: frameDelay) {
            restartTimer()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 12) {
            if currentFrameIndex < images.count {
                Image(uiImage: images[currentFrameIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Frame \(currentFrameIndex + 1) of \(images.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            // Frame delay
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

            // Loop toggle
            HStack {
                Text("Loop Forever")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Toggle("", isOn: $loopForever)
                    .labelsHidden()
            }

            // Frame count
            HStack {
                Text("\(images.count) frames")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "~%.1fs total", Double(images.count) * frameDelay))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Apply button
            Button {
                isApplying = true
                stopTimer()
                Task {
                    if let (thumbnail, url) = renderGIF() {
                        await onApply(thumbnail, url)
                    }
                    isApplying = false
                }
            } label: {
                if isApplying {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Create GIF")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isApplying)
        }
        .padding(20)
        .background(.bar)
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: frameDelay, repeats: true) { _ in
            currentFrameIndex = (currentFrameIndex + 1) % images.count
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

    // MARK: - Render GIF

    private func renderGIF() -> (UIImage, URL)? {
        let outputName = "animated_\(UUID().uuidString.prefix(8)).gif"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Determine target size from first image
        guard let firstImage = images.first else { return nil }
        let targetSize = firstImage.size

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            images.count,
            nil
        ) else { return nil }

        // GIF file properties (loop count)
        let gifFileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: loopForever ? 0 : 1
            ]
        ]
        CGImageDestinationSetProperties(destination, gifFileProperties as CFDictionary)

        // Frame properties
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay
            ]
        ]

        for image in images {
            // Normalize orientation and resize to match first image
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let normalized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            guard let cgImage = normalized.cgImage else { continue }
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else { return nil }

        // Return first frame as thumbnail
        return (firstImage, outputURL)
    }
}
