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

    var usesFFmpeg: Bool {
        switch self {
        case .jp2, .tiff: return true
        default: return false
        }
    }
}

struct ImageCompressView: View {
    let fileURL: URL
    let fileName: String
    let onApply: (String, Double) -> Void

    @State private var previewImage: UIImage?
    @State private var selectedFormat: CompressFormat = .jpeg
    @State private var quality: Double = 80
    @State private var originalSize: Int64 = 0
    @State private var estimatedSize: Int64 = 0
    @State private var estimationTask: Task<Void, Never>?
    @State private var imageSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            preview

            Spacer()

            controls
        }
        .navigationTitle("Compress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            previewImage = ImageConverterViewModel.loadPreviewImage(from: fileURL)
            imageSize = ImageConverterViewModel.imageDimensions(from: fileURL) ?? .zero
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
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ProgressView()
                    .frame(height: 300)
            }

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
            VStack(spacing: 8) {
                Text("Format")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                formatPicker
            }

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

            Button {
                onApply(selectedFormat.fileExtension, quality)
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
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            let estimated = estimateCompressedSize()
            await MainActor.run {
                estimatedSize = estimated
            }
        }
    }

    private func estimateCompressedSize() -> Int64 {
        if selectedFormat.usesFFmpeg {
            let pixelCount = imageSize.width * imageSize.height
            let bytesPerPixel: Double
            switch selectedFormat {
            case .jp2:
                bytesPerPixel = selectedFormat.isLossy ? (quality / 100) * 3.0 : 3.0
            case .tiff:
                bytesPerPixel = 3.0
            default:
                bytesPerPixel = 1.0
            }
            return Int64(pixelCount * bytesPerPixel)
        }

        // Use the preview image for estimation (already downsampled)
        guard let sample = previewImage else { return 0 }

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
            sampleData = nil
        }

        guard let data = sampleData else { return 0 }

        // Extrapolate from preview to full size
        let previewPixels = sample.size.width * sample.size.height
        let fullPixels = imageSize.width * imageSize.height
        if previewPixels > 0 && fullPixels > previewPixels {
            let pixelRatio = fullPixels / previewPixels
            return Int64(Double(data.count) * pixelRatio)
        }
        return Int64(data.count)
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
        if bytes == 0 { return "\u{2014}" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
