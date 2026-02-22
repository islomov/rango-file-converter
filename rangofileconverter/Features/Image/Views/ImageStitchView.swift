import SwiftUI

private enum StitchLayout: String, CaseIterable {
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case grid = "Grid"
}

private enum StitchBackground: String, CaseIterable {
    case white = "White"
    case black = "Black"
    case transparent = "Clear"

    var color: UIColor {
        switch self {
        case .white: return .white
        case .black: return .black
        case .transparent: return .clear
        }
    }
}

struct ImageStitchView: View {
    let images: [UIImage]
    let fileNames: [String]
    let onApply: (UIImage, URL) async -> Void

    @State private var layout: StitchLayout = .horizontal
    @State private var background: StitchBackground = .white
    @State private var isApplying = false
    @State private var previewImage: UIImage?

    private let gap: CGFloat = 8

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
                    Text("Stitching...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationTitle("Stitch")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { updatePreview() }
        .onChange(of: layout) { updatePreview() }
        .onChange(of: background) { updatePreview() }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 12) {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    )
            }

            if let size = previewImage?.size {
                Text("\(images.count) images · \(Int(size.width))×\(Int(size.height))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Layout")
                    .font(.subheadline.weight(.medium))
                Picker("Layout", selection: $layout) {
                    ForEach(StitchLayout.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Background")
                    .font(.subheadline.weight(.medium))
                Picker("Background", selection: $background) {
                    ForEach(StitchBackground.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("\(images.count) images")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                isApplying = true
                Task {
                    if let (result, url) = renderStitch(preview: false) {
                        await onApply(result, url)
                    }
                    isApplying = false
                }
            } label: {
                if isApplying {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Stitch Images")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
            .disabled(isApplying)
        }
        .padding(20)
        .background(.bar)
    }

    // MARK: - Rendering

    private func updatePreview() {
        previewImage = renderStitch(preview: true)?.0
    }

    private func renderStitch(preview: Bool) -> (UIImage, URL)? {
        guard !images.isEmpty else { return nil }

        let scale: CGFloat = preview ? 0.25 : 1.0
        let scaledGap = gap * (preview ? 1 : 2)

        let scaledImages: [UIImage] = images.map { img in
            if preview {
                let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                return renderer.image { _ in
                    img.draw(in: CGRect(origin: .zero, size: newSize))
                }
            }
            return img
        }

        let canvasSize: CGSize
        let drawRects: [CGRect]

        switch layout {
        case .horizontal:
            (canvasSize, drawRects) = layoutHorizontal(scaledImages, gap: scaledGap)
        case .vertical:
            (canvasSize, drawRects) = layoutVertical(scaledImages, gap: scaledGap)
        case .grid:
            (canvasSize, drawRects) = layoutGrid(scaledImages, gap: scaledGap)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = background != .transparent

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let result = renderer.image { ctx in
            background.color.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            for (i, rect) in drawRects.enumerated() where i < scaledImages.count {
                let img = scaledImages[i]
                let fitted = aspectFitRect(imageSize: img.size, in: rect)
                img.draw(in: fitted)
            }
        }

        if preview {
            return (result, URL(fileURLWithPath: ""))
        }

        let outputName = "stitch_\(UUID().uuidString.prefix(8)).png"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let data = result.pngData() else { return nil }
        do {
            try data.write(to: outputURL)
        } catch {
            return nil
        }

        return (result, outputURL)
    }

    // MARK: - Layout Calculations

    private func layoutHorizontal(_ images: [UIImage], gap: CGFloat) -> (CGSize, [CGRect]) {
        let maxHeight = images.map(\.size.height).max() ?? 0
        var rects: [CGRect] = []
        var x: CGFloat = 0

        for img in images {
            let scale = maxHeight / img.size.height
            let w = img.size.width * scale
            rects.append(CGRect(x: x, y: 0, width: w, height: maxHeight))
            x += w + gap
        }

        let totalWidth = x - (images.isEmpty ? 0 : gap)
        return (CGSize(width: totalWidth, height: maxHeight), rects)
    }

    private func layoutVertical(_ images: [UIImage], gap: CGFloat) -> (CGSize, [CGRect]) {
        let maxWidth = images.map(\.size.width).max() ?? 0
        var rects: [CGRect] = []
        var y: CGFloat = 0

        for img in images {
            let scale = maxWidth / img.size.width
            let h = img.size.height * scale
            rects.append(CGRect(x: 0, y: y, width: maxWidth, height: h))
            y += h + gap
        }

        let totalHeight = y - (images.isEmpty ? 0 : gap)
        return (CGSize(width: maxWidth, height: totalHeight), rects)
    }

    private func layoutGrid(_ images: [UIImage], gap: CGFloat) -> (CGSize, [CGRect]) {
        let count = images.count
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))

        let maxW = images.map(\.size.width).max() ?? 0
        let maxH = images.map(\.size.height).max() ?? 0

        let cellW = maxW
        let cellH = maxH
        let totalWidth = CGFloat(cols) * cellW + CGFloat(cols - 1) * gap
        let totalHeight = CGFloat(rows) * cellH + CGFloat(rows - 1) * gap

        var rects: [CGRect] = []
        for i in 0..<count {
            let col = i % cols
            let row = i / cols
            let x = CGFloat(col) * (cellW + gap)
            let y = CGFloat(row) * (cellH + gap)
            rects.append(CGRect(x: x, y: y, width: cellW, height: cellH))
        }

        return (CGSize(width: totalWidth, height: totalHeight), rects)
    }

    private func aspectFitRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        let widthRatio = rect.width / imageSize.width
        let heightRatio = rect.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        let fittedWidth = imageSize.width * scale
        let fittedHeight = imageSize.height * scale
        let x = rect.origin.x + (rect.width - fittedWidth) / 2
        let y = rect.origin.y + (rect.height - fittedHeight) / 2
        return CGRect(x: x, y: y, width: fittedWidth, height: fittedHeight)
    }
}
