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

    @Environment(\.dismiss) private var dismiss
    @State private var layout: StitchLayout = .horizontal
    @State private var background: StitchBackground = .white
    @State private var previewImage: UIImage?
    @State private var previewFrames: [UIImage] = []
    @State private var imageSizes: [CGSize] = []

    private let gap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            previewSection
            controlsSection
            Spacer(minLength: 0)
            bottomButtons
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .onAppear {
            loadPreviews()
            updatePreview()
        }
        .onChange(of: layout) { _ in updatePreview() }
        .onChange(of: background) { _ in updatePreview() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Stitch images")
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
                        .background(Circle().fill(AppColors.textSecondary.opacity(0.08)))
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.shadow.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                ProgressView()
                    .frame(height: 260)
                    .padding(.vertical, 24)
            }

            imageInfo
                .padding(.bottom, 12)
        }
        .background(AppColors.surface)
        .overlay(
            Rectangle().fill(AppColors.shadow.opacity(0.08)).frame(height: 1),
            alignment: .bottom
        )
    }

    private var imageInfo: some View {
        HStack(spacing: 4) {
            Text("\(fileURLs.count) images")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            if let size = previewImage?.size {
                Text("\u{00B7}")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Text("\(Int(size.width))\u{00D7}\(Int(size.height))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(-0.408)
            }
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Layout")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                HStack(spacing: 8) {
                    ForEach(StitchLayout.allCases, id: \.self) { option in
                        chipButton(
                            title: LocalizedStringKey(option.rawValue),
                            icon: layoutIcon(for: option),
                            isSelected: layout == option
                        ) {
                            layout = option
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Background")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                HStack(spacing: 8) {
                    ForEach(StitchBackground.allCases, id: \.self) { option in
                        chipButton(
                            title: LocalizedStringKey(option.rawValue),
                            icon: nil,
                            isSelected: background == option
                        ) {
                            background = option
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func chipButton(title: LocalizedStringKey, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.408)
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                isSelected
                    ? AnyShapeStyle(AppColors.accent)
                    : AnyShapeStyle(AppColors.textSecondary.opacity(0.08))
            )
            .clipShape(Capsule())
        }
    }

    private func layoutIcon(for layout: StitchLayout) -> String {
        switch layout {
        case .horizontal: return "rectangle.split.3x1"
        case .vertical: return "rectangle.split.1x2"
        case .grid: return "rectangle.split.2x2"
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let spacing: CGFloat = 8
            let resetWidth = (totalWidth - spacing) * 0.3
            let actionWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                Button {
                    layout = .horizontal
                    background = .white
                } label: {
                    Text("Reset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .frame(width: resetWidth, height: 60)
                        .background(AppColors.textSecondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    onApply(layout.rawValue, background.rawValue)
                } label: {
                    Text("Stitch Images")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: actionWidth, height: 60)
                        .background(
                            LinearGradient(
                                colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
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
