import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import webp

private enum CompressFormat: String, CaseIterable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    case webp = "WebP"
    case jp2 = "JP2"
    case tiff = "TIFF"

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .webp: return "webp"
        case .jp2: return "jp2"
        case .tiff: return "tiff"
        }
    }

    var isLossy: Bool {
        switch self {
        case .png, .tiff: return false
        default: return true
        }
    }

    /// Whether this format requires FFmpeg for encoding.
    var usesFFmpeg: Bool {
        switch self {
        case .jp2, .tiff: return true
        default: return false
        }
    }
}

struct ImageCompressView: View {
    let image: UIImage
    let fileName: String
    let fileURL: URL
    let onApply: (UIImage, URL) async -> Void

    @State private var selectedFormat: CompressFormat = .jpeg
    @State private var quality: Double = 80
    @State private var isApplying = false
    @State private var originalSize: Int64 = 0
    @State private var estimatedSize: Int64 = 0
    @State private var estimationTask: Task<Void, Never>?

    private let coordinator = ConversionCoordinator()

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
                    Text("Compressing...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationTitle("Compress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadOriginalSize()
            updateEstimatedSize()
        }
        .onChange(of: quality) { _ in
            updateEstimatedSize()
        }
        .onChange(of: selectedFormat) { _ in
            updateEstimatedSize()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // File size comparison
            HStack(spacing: 8) {
                Text(formatBytes(originalSize))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(formatBytes(estimatedSize))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(estimatedSize < originalSize ? .green : .orange)

                if originalSize > 0 && estimatedSize > 0 {
                    let ratio = Double(estimatedSize) / Double(originalSize) * 100
                    Text(String(format: "(%.0f%%)", ratio))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            // Format picker
            VStack(spacing: 8) {
                Text("Format")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                formatPicker
            }

            // Quality slider (hidden for lossless formats)
            if selectedFormat.isLossy {
                VStack(spacing: 8) {
                    HStack {
                        Text("Quality")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(quality))%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $quality, in: 1...100, step: 1)
                }
            } else {
                HStack {
                    Text("Quality")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("Lossless")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Apply button
            Button {
                isApplying = true
                Task {
                    if let (thumbnail, url) = await renderCompressed() {
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
                    Text("Compress")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(isApplying)
        }
        .padding(20)
        .background(.bar)
    }

    private var formatPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CompressFormat.allCases, id: \.self) { format in
                    Button {
                        selectedFormat = format
                    } label: {
                        Text(format.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedFormat == format ? Color.purple : Color(.systemGray5),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedFormat == format ? .white : .primary)
                    }
                }
            }
        }
    }

    // MARK: - File Size

    private func loadOriginalSize() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64 {
            originalSize = size
        }
    }

    private func updateEstimatedSize() {
        estimationTask?.cancel()
        estimationTask = Task {
            // Small debounce
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            let estimated = estimateCompressedSize()
            await MainActor.run {
                estimatedSize = estimated
            }
        }
    }

    private func estimateCompressedSize() -> Int64 {
        // FFmpeg formats can't be estimated quickly in-process
        if selectedFormat.usesFFmpeg {
            // Rough estimate based on format characteristics
            let pixelCount = image.size.width * image.size.height
            let bytesPerPixel: Double
            switch selectedFormat {
            case .jp2:
                bytesPerPixel = selectedFormat.isLossy ? (quality / 100) * 3.0 : 3.0
            case .tiff:
                bytesPerPixel = 3.0 // Uncompressed TIFF ~3 bytes/pixel for RGB
            default:
                bytesPerPixel = 1.0
            }
            return Int64(pixelCount * bytesPerPixel)
        }

        // Use a scaled-down version for fast estimation (native formats)
        let maxDim: CGFloat = 800
        let scale = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
        let sampleSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: sampleSize)
        let sample = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: sampleSize))
        }

        let sampleData: Data?
        switch selectedFormat {
        case .jpeg:
            sampleData = sample.jpegData(compressionQuality: quality / 100)
        case .png:
            sampleData = sample.pngData()
        case .heic:
            sampleData = encodeHEICData(from: sample, quality: quality / 100)
        case .webp:
            sampleData = try? encodeWebPData(from: sample, quality: quality / 100)
        case .jp2, .tiff:
            sampleData = nil // Handled above
        }

        guard let data = sampleData else { return 0 }

        // Extrapolate from sample to full size
        if scale < 1.0 {
            let pixelRatio = (image.size.width * image.size.height) / (sampleSize.width * sampleSize.height)
            return Int64(Double(data.count) * pixelRatio)
        }
        return Int64(data.count)
    }

    // MARK: - Render

    private func renderCompressed() async -> (UIImage, URL)? {
        if selectedFormat.usesFFmpeg {
            return await renderViaFFmpeg()
        }
        return renderNative()
    }

    private func renderNative() -> (UIImage, URL)? {
        // Normalize orientation
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        let outputName = "compressed_\(UUID().uuidString.prefix(8)).\(selectedFormat.fileExtension)"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data: Data?
        switch selectedFormat {
        case .jpeg:
            data = normalized.jpegData(compressionQuality: quality / 100)
        case .png:
            data = normalized.pngData()
        case .heic:
            data = encodeHEICData(from: normalized, quality: quality / 100)
        case .webp:
            data = try? encodeWebPData(from: normalized, quality: quality / 100)
        case .jp2, .tiff:
            data = nil // Handled by renderViaFFmpeg
        }

        guard let outputData = data else { return nil }

        do {
            try outputData.write(to: outputURL)
            return (normalized, outputURL)
        } catch {
            return nil
        }
    }

    private func renderViaFFmpeg() async -> (UIImage, URL)? {
        guard let formatDef = FormatRegistry.format(forExtension: selectedFormat.fileExtension) else {
            return nil
        }

        var job = ConversionJob(inputURL: fileURL, outputFormat: formatDef)
        if selectedFormat.isLossy {
            job.quality = Int(quality)
        }

        do {
            let result = try await coordinator.convert(job: job)
            return (image, result.outputURL)
        } catch {
            return nil
        }
    }

    // MARK: - Encoders

    private func encodeHEICData(from image: UIImage, quality: Double) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func encodeWebPData(from image: UIImage, quality: Double) throws -> Data {
        try WebPEncoder().encode(image, config: .preset(.picture, quality: Float(quality * 100)))
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
