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
    let fileURLs: [URL]
    let fileNames: [String]
    let onApply: (String, String) -> Void

    @State private var layout: StitchLayout = .horizontal
    @State private var background: StitchBackground = .white
    @State private var previewImage: UIImage?
    @State private var previewFrames: [UIImage] = []
    @State private var imageSizes: [CGSize] = []

    private let gap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            preview
            Spacer()
            controls
        }
        .navigationTitle("Stitch")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPreviews()
            updatePreview()
        }
        .onChange(of: layout) { _ in updatePreview() }
        .onChange(of: background) { _ in updatePreview() }
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
                Text("\(fileURLs.count) images \u{00B7} \(Int(size.width))\u{00D7}\(Int(size.height))")
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
                Text("\(fileURLs.count) images")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                onApply(layout.rawValue, background.rawValue)
            } label: {
                Text("Stitch Images")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
        }
        .padding(20)
        .background(.bar)
    }

    // MARK: - Preview Loading & Rendering

    private func loadPreviews() {
        previewFrames = fileURLs.compactMap { url in
            ImageConverterViewModel.loadPreviewImage(from: url, maxPixelSize: 400)
        }
        imageSizes = previewFrames.map(\.size)
    }

    private func updatePreview() {
        previewImage = renderPreview()
    }

    private func renderPreview() -> UIImage? {
        guard !previewFrames.isEmpty, imageSizes.count == previewFrames.count else { return nil }

        let canvasSize: CGSize
        let drawRects: [CGRect]

        switch layout {
        case .horizontal:
            (canvasSize, drawRects) = layoutHorizontal(imageSizes, gap: gap)
        case .vertical:
            (canvasSize, drawRects) = layoutVertical(imageSizes, gap: gap)
        case .grid:
            (canvasSize, drawRects) = layoutGrid(imageSizes, gap: gap)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = background != .transparent

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            background.color.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            for (i, rect) in drawRects.enumerated() where i < previewFrames.count {
                let img = previewFrames[i]
                let fitted = aspectFitRect(imageSize: img.size, in: rect)
                img.draw(in: fitted)
            }
        }
    }

    // MARK: - Layout Calculations

    private func layoutHorizontal(_ sizes: [CGSize], gap: CGFloat) -> (CGSize, [CGRect]) {
        let maxHeight = sizes.map(\.height).max() ?? 0
        var rects: [CGRect] = []
        var x: CGFloat = 0

        for size in sizes {
            let scale = maxHeight / size.height
            let w = size.width * scale
            rects.append(CGRect(x: x, y: 0, width: w, height: maxHeight))
            x += w + gap
        }

        let totalWidth = x - (sizes.isEmpty ? 0 : gap)
        return (CGSize(width: totalWidth, height: maxHeight), rects)
    }

    private func layoutVertical(_ sizes: [CGSize], gap: CGFloat) -> (CGSize, [CGRect]) {
        let maxWidth = sizes.map(\.width).max() ?? 0
        var rects: [CGRect] = []
        var y: CGFloat = 0

        for size in sizes {
            let scale = maxWidth / size.width
            let h = size.height * scale
            rects.append(CGRect(x: 0, y: y, width: maxWidth, height: h))
            y += h + gap
        }

        let totalHeight = y - (sizes.isEmpty ? 0 : gap)
        return (CGSize(width: maxWidth, height: totalHeight), rects)
    }

    private func layoutGrid(_ sizes: [CGSize], gap: CGFloat) -> (CGSize, [CGRect]) {
        let count = sizes.count
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))

        let maxW = sizes.map(\.width).max() ?? 0
        let maxH = sizes.map(\.height).max() ?? 0

        let totalWidth = CGFloat(cols) * maxW + CGFloat(cols - 1) * gap
        let totalHeight = CGFloat(rows) * maxH + CGFloat(rows - 1) * gap

        var rects: [CGRect] = []
        for i in 0..<count {
            let col = i % cols
            let row = i / cols
            let x = CGFloat(col) * (maxW + gap)
            let y = CGFloat(row) * (maxH + gap)
            rects.append(CGRect(x: x, y: y, width: maxW, height: maxH))
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
