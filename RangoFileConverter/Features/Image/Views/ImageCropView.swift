import SwiftUI

private enum ImageAspectRatio: String, CaseIterable, Identifiable {
    case free = "Free"
    case r16_9 = "16:9"
    case r9_16 = "9:16"
    case r4_3 = "4:3"
    case r3_4 = "3:4"
    case r1_1 = "1:1"
    case r21_9 = "21:9"

    var id: String { rawValue }

    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .r16_9: return 16.0 / 9.0
        case .r9_16: return 9.0 / 16.0
        case .r4_3: return 4.0 / 3.0
        case .r3_4: return 3.0 / 4.0
        case .r1_1: return 1.0
        case .r21_9: return 21.0 / 9.0
        }
    }

    var iconWidth: CGFloat {
        switch self {
        case .free: return 24
        case .r16_9: return 36
        case .r9_16: return 20
        case .r4_3: return 28
        case .r3_4: return 20
        case .r1_1: return 24
        case .r21_9: return 38
        }
    }

    var iconHeight: CGFloat {
        switch self {
        case .free: return 24
        case .r16_9: return 22
        case .r9_16: return 32
        case .r4_3: return 22
        case .r3_4: return 28
        case .r1_1: return 24
        case .r21_9: return 18
        }
    }
}

private enum CropFitMode: String, CaseIterable {
    case crop = "Crop"
    case pad = "Pad"
}

private enum HandlePosition: Int, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

struct ImageCropView: View {
    let fileURL: URL
    let fileName: String
    let onApply: (CGRect) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewImage: UIImage?
    @State private var imageSize: CGSize = .zero
    @State private var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var selectedRatio: ImageAspectRatio = .free
    @State private var fitMode: CropFitMode = .crop
    @State private var imageFrame: CGRect = .zero
    @State private var originalSize: Int64 = 0

    // Drag state
    @State private var activeHandle: HandlePosition?
    @State private var isDraggingRect = false
    @State private var dragStartRect: CGRect = .zero

    private var hasChanges: Bool {
        selectedRatio != .free || cropRect != CGRect(x: 0, y: 0, width: 1, height: 1)
    }

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
            imageSize = ImageConverterViewModel.imageDimensions(from: fileURL) ?? .zero
            previewImage = ImageConverterViewModel.loadPreviewImage(from: fileURL)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                originalSize = size
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Crop image")
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

            GeometryReader { geo in
                ZStack {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background(
                                GeometryReader { imgGeo in
                                    Color.clear
                                        .onAppear {
                                            imageFrame = imgGeo.frame(in: .named("cropCanvas"))
                                        }
                                        .onChange(of: geo.size) { _ in
                                            imageFrame = imgGeo.frame(in: .named("cropCanvas"))
                                        }
                                }
                            )
                    } else {
                        ProgressView()
                    }

                    if imageFrame.width > 0 {
                        cropOverlay
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .coordinateSpace(name: "cropCanvas")
            }
            .frame(height: 260)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            fileSizeInfo
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

    private var fileSizeInfo: some View {
        HStack(spacing: 4) {
            Text("\(Int(imageSize.width)) \u{00D7} \(Int(imageSize.height))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            if hasChanges {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textPrimary)

                Text("\(pixelWidth) \u{00D7} \(pixelHeight)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(-0.408)

                if imageSize.width > 0 && imageSize.height > 0 {
                    let originalPixels = Double(imageSize.width * imageSize.height)
                    let cropPixels = Double(pixelWidth * pixelHeight)
                    let ratio = cropPixels / originalPixels * 100
                    Text(String(format: "(%.0f%%)", ratio))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }
            }
        }
    }

    // MARK: - Crop Overlay

    private var cropOverlay: some View {
        let viewRect = toViewRect(cropRect)
        return ZStack {
            Canvas { ctx, size in
                var path = Path()
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRect(viewRect)
                ctx.fill(path, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
            }
            .allowsHitTesting(false)

            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: viewRect.width, height: viewRect.height)
                .position(x: viewRect.midX, y: viewRect.midY)
                .allowsHitTesting(false)

            Path { path in
                let thirdW = viewRect.width / 3
                let thirdH = viewRect.height / 3
                for i in 1...2 {
                    let x = viewRect.minX + thirdW * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: viewRect.minY))
                    path.addLine(to: CGPoint(x: x, y: viewRect.maxY))
                    let y = viewRect.minY + thirdH * CGFloat(i)
                    path.move(to: CGPoint(x: viewRect.minX, y: y))
                    path.addLine(to: CGPoint(x: viewRect.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            .allowsHitTesting(false)

            ForEach(HandlePosition.allCases, id: \.rawValue) { handle in
                let pt = handle.point(in: viewRect)
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(pt)
                    .allowsHitTesting(false)
            }

            // Invisible hit target covering the full canvas for drag gestures
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .named("cropCanvas"))
                        .onChanged { value in
                            if activeHandle == nil && !isDraggingRect {
                                dragStartRect = cropRect
                                let (handle, dist) = closestHandle(to: value.startLocation)
                                let viewRect = toViewRect(cropRect)
                                let insideCrop = viewRect.insetBy(dx: -20, dy: -20).contains(value.startLocation)
                                if insideCrop && dist > 40 {
                                    isDraggingRect = true
                                } else {
                                    activeHandle = handle
                                }
                            }

                            if isDraggingRect {
                                moveCropRect(translation: value.translation)
                            } else if let handle = activeHandle {
                                updateCrop(handle: handle, location: value.location)
                            }
                        }
                        .onEnded { _ in
                            activeHandle = nil
                            isDraggingRect = false
                            dragStartRect = .zero
                        }
                )
        }
    }

    private func closestHandle(to point: CGPoint) -> (HandlePosition, CGFloat) {
        let viewRect = toViewRect(cropRect)
        var best: HandlePosition = .bottomRight
        var bestDist: CGFloat = .infinity
        for handle in HandlePosition.allCases {
            let hp = handle.point(in: viewRect)
            let dist = hypot(point.x - hp.x, point.y - hp.y)
            if dist < bestDist {
                bestDist = dist
                best = handle
            }
        }
        return (best, bestDist)
    }

    private func moveCropRect(translation: CGSize) {
        let dx = translation.width / imageFrame.width
        let dy = translation.height / imageFrame.height

        var newRect = dragStartRect
        newRect.origin.x = dragStartRect.origin.x + dx
        newRect.origin.y = dragStartRect.origin.y + dy

        newRect.origin.x = max(0, min(newRect.origin.x, 1 - newRect.width))
        newRect.origin.y = max(0, min(newRect.origin.y, 1 - newRect.height))

        cropRect = newRect
    }

    // MARK: - Gesture Logic

    private func updateCrop(handle: HandlePosition, location: CGPoint) {
        let norm = toNormalized(location)
        var rect = dragStartRect
        let minSize: CGFloat = 0.05

        switch handle {
        case .topLeft:
            rect.origin.x = min(norm.x, dragStartRect.maxX - minSize)
            rect.origin.y = min(norm.y, dragStartRect.maxY - minSize)
            rect.size.width = dragStartRect.maxX - rect.origin.x
            rect.size.height = dragStartRect.maxY - rect.origin.y
        case .top:
            rect.origin.y = min(norm.y, dragStartRect.maxY - minSize)
            rect.size.height = dragStartRect.maxY - rect.origin.y
        case .topRight:
            rect.size.width = max(norm.x - dragStartRect.minX, minSize)
            rect.origin.y = min(norm.y, dragStartRect.maxY - minSize)
            rect.size.height = dragStartRect.maxY - rect.origin.y
        case .right:
            rect.size.width = max(norm.x - dragStartRect.minX, minSize)
        case .bottomRight:
            rect.size.width = max(norm.x - dragStartRect.minX, minSize)
            rect.size.height = max(norm.y - dragStartRect.minY, minSize)
        case .bottom:
            rect.size.height = max(norm.y - dragStartRect.minY, minSize)
        case .bottomLeft:
            rect.origin.x = min(norm.x, dragStartRect.maxX - minSize)
            rect.size.width = dragStartRect.maxX - rect.origin.x
            rect.size.height = max(norm.y - dragStartRect.minY, minSize)
        case .left:
            rect.origin.x = min(norm.x, dragStartRect.maxX - minSize)
            rect.size.width = dragStartRect.maxX - rect.origin.x
        }

        rect.origin.x = max(0, rect.origin.x)
        rect.origin.y = max(0, rect.origin.y)
        rect.size.width = min(rect.width, 1 - rect.origin.x)
        rect.size.height = min(rect.height, 1 - rect.origin.y)

        if let ratio = selectedRatio.ratio {
            rect = enforceRatio(rect, ratio: ratio, handle: handle)
        }

        cropRect = rect
    }

    private func enforceRatio(_ rect: CGRect, ratio: CGFloat, handle: HandlePosition) -> CGRect {
        var r = rect
        let imgW = imageSize.width
        let imgH = imageSize.height

        let pixW = r.width * imgW
        let pixH = r.height * imgH
        let currentRatio = pixW / pixH

        if abs(currentRatio - ratio) < 0.01 { return r }

        let isVertical = handle == .top || handle == .bottom
        let isHorizontal = handle == .left || handle == .right

        if isVertical {
            let newPixW = pixH * ratio
            let newNormW = newPixW / imgW
            let delta = newNormW - r.width
            r.origin.x = max(0, r.origin.x - delta / 2)
            r.size.width = min(newNormW, 1 - r.origin.x)
        } else if isHorizontal {
            let newPixH = pixW / ratio
            let newNormH = newPixH / imgH
            let delta = newNormH - r.height
            r.origin.y = max(0, r.origin.y - delta / 2)
            r.size.height = min(newNormH, 1 - r.origin.y)
        } else {
            let newPixH = pixW / ratio
            let newNormH = newPixH / imgH
            if handle == .topLeft || handle == .topRight {
                let bottom = r.maxY
                r.size.height = min(newNormH, bottom)
                r.origin.y = bottom - r.size.height
            } else {
                r.size.height = min(newNormH, 1 - r.origin.y)
            }
        }

        return r
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Aspect ratio grid
            ratioGrid

            // Fit mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Fit mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                HStack(spacing: 8) {
                    ForEach(CropFitMode.allCases, id: \.self) { mode in
                        Button {
                            fitMode = mode
                        } label: {
                            Text(LocalizedStringKey(mode.rawValue))
                                .font(.system(size: 14, weight: .semibold))
                                .tracking(-0.408)
                                .foregroundColor(fitMode == mode ? .white : AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    fitMode == mode
                                        ? AppColors.accent
                                        : AppColors.textSecondary.opacity(0.08)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private var ratioGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ImageAspectRatio.allCases.filter { $0 != .free }) { ratio in
                Button {
                    applyAspectRatio(ratio)
                } label: {
                    VStack(spacing: 4) {
                        RatioIconView(ratio: ratio)
                        Text(LocalizedStringKey(ratio.rawValue))
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(-0.37)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .background(
                        selectedRatio == ratio
                            ? AppColors.accent.opacity(0.08)
                            : AppColors.textSecondary.opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedRatio == ratio ? AppColors.accentLight : .clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let spacing: CGFloat = 8
            let resetWidth = (totalWidth - spacing) * 0.3
            let applyWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                        selectedRatio = .free
                        fitMode = .crop
                    }
                } label: {
                    Text("Reset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .frame(width: resetWidth, height: 60)
                        .background(AppColors.textSecondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!hasChanges)
                .opacity(hasChanges ? 1.0 : 0.5)

                Button {
                    onApply(cropRect)
                } label: {
                    Text("Apply crop")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: applyWidth, height: 60)
                        .background(
                            LinearGradient(
                                colors: hasChanges
                                    ? [AppColors.buttonGradientStart, AppColors.buttonGradientEnd]
                                    : [AppColors.buttonDisabledStart, AppColors.buttonDisabledMid, AppColors.buttonDisabledStart],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!hasChanges)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 60)
        .padding(.vertical, 24)
    }

    // MARK: - Computed

    private var pixelWidth: Int {
        Int(cropRect.width * imageSize.width)
    }

    private var pixelHeight: Int {
        Int(cropRect.height * imageSize.height)
    }

    // MARK: - Coordinate Conversion

    private func toViewRect(_ normalized: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.minX + normalized.minX * imageFrame.width,
            y: imageFrame.minY + normalized.minY * imageFrame.height,
            width: normalized.width * imageFrame.width,
            height: normalized.height * imageFrame.height
        )
    }

    private func toNormalized(_ viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (viewPoint.x - imageFrame.minX) / imageFrame.width,
            y: (viewPoint.y - imageFrame.minY) / imageFrame.height
        )
    }

    // MARK: - Aspect Ratio

    private func applyAspectRatio(_ ratio: ImageAspectRatio) {
        selectedRatio = ratio
        guard let r = ratio.ratio else {
            // Free mode — reset to full image
            withAnimation(.easeInOut(duration: 0.2)) {
                cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            }
            return
        }

        let imgW = imageSize.width
        let imgH = imageSize.height

        var normW: CGFloat
        var normH: CGFloat

        let fullPixW = imgW
        let fullPixH = fullPixW / r

        if fullPixH <= imgH {
            normW = 1.0
            normH = fullPixH / imgH
        } else {
            normH = 1.0
            normW = (imgH * r) / imgW
        }

        var newRect = CGRect(
            x: (1 - normW) / 2,
            y: (1 - normH) / 2,
            width: normW,
            height: normH
        )

        newRect.origin.x = max(0, min(newRect.origin.x, 1 - newRect.width))
        newRect.origin.y = max(0, min(newRect.origin.y, 1 - newRect.height))

        withAnimation(.easeInOut(duration: 0.2)) {
            cropRect = newRect
        }
    }
}

// MARK: - Ratio Icon View

private struct RatioIconView: View {
    let ratio: ImageAspectRatio

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .stroke(AppColors.textPrimary, lineWidth: 1.5)
            .frame(width: ratio.iconWidth, height: ratio.iconHeight)
    }
}
