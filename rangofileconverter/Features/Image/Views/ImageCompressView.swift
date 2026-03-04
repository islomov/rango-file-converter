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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            controlsSection

            Spacer(minLength: 0)

            bottomButtons
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
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

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Compress image")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(hex: "888888").opacity(0.08))
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

            if let previewImage {
                Image(uiImage: previewImage)
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

            fileSizeInfo
                .padding(.bottom, 12)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var fileSizeInfo: some View {
        HStack(spacing: 4) {
            Text(formatBytes(originalSize))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "1D1D1D"))

            Text(formatBytes(estimatedSize))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "F4800D"))
                .tracking(-0.408)

            if originalSize > 0 && estimatedSize > 0 {
                let ratio = Double(estimatedSize) / Double(originalSize) * 100
                Text(String(format: "(%.0f%%)", ratio))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "888888"))
                    .tracking(-0.408)
            }
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "888888"))
                    .tracking(-0.408)

                formatPicker
            }

            // Quality
            if selectedFormat.isLossy {
                VStack(spacing: 12) {
                    HStack {
                        Text("Quality")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                            .tracking(-0.408)
                        Spacer()
                        Text("\(Int(quality))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                            .tracking(-0.408)
                    }

                    Slider(value: $quality, in: 1...100, step: 1)
                        .tint(Color(hex: "F4800D"))
                }
            } else {
                HStack {
                    Text("Quality")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "888888"))
                        .tracking(-0.408)
                    Spacer()
                    Text("Lossless")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "888888"))
                        .tracking(-0.408)
                }
            }
        }
        .padding(16)
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach([CompressFormat.jpeg, .png, .heic, .webp], id: \.self) { format in
                    formatButton(format)
                }
            }
            HStack(spacing: 4) {
                formatButton(.jp2)
                    .frame(width: 86.5)
                formatButton(.tiff)
                    .frame(width: 86.5)
                Spacer()
            }
        }
    }

    private func formatButton(_ format: CompressFormat) -> some View {
        Button {
            selectedFormat = format
        } label: {
            Text(format.rawValue)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(
                    selectedFormat == format
                        ? Color(hex: "F4800D")
                        : Color(hex: "1D1D1D")
                )
                .tracking(-0.408)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selectedFormat == format
                        ? Color(hex: "F4800D").opacity(0.08)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let spacing: CGFloat = 8
            let resetWidth = (totalWidth - spacing) * 0.3
            let compressWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                // Reset button (30%)
                Button {
                    selectedFormat = .jpeg
                    quality = 80
                } label: {
                    Text("Reset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .tracking(-0.408)
                        .frame(width: resetWidth, height: 60)
                        .background(Color(hex: "888888").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Compress button (70%)
                Button {
                    onApply(selectedFormat.fileExtension, quality)
                } label: {
                    Text("Compress")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: compressWidth, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FFA05C"), Color(hex: "EF731A")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 60)
        .padding(.vertical, 24)
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
