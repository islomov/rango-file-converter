import SwiftUI

private enum AspectRatio: CaseIterable, Identifiable {
    case free
    case square
    case fourThree
    case threeTwo
    case sixteenNine

    var id: String { label(isPortrait: false) }

    /// Display label adapts to image orientation
    func label(isPortrait: Bool) -> String {
        switch self {
        case .free: return "Free"
        case .square: return "1:1"
        case .fourThree: return isPortrait ? "3:4" : "4:3"
        case .threeTwo: return isPortrait ? "2:3" : "3:2"
        case .sixteenNine: return isPortrait ? "9:16" : "16:9"
        }
    }

    /// Returns width/height ratio adapted to image orientation
    func ratio(isPortrait: Bool) -> CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1
        case .fourThree: return isPortrait ? 3.0 / 4.0 : 4.0 / 3.0
        case .threeTwo: return isPortrait ? 2.0 / 3.0 : 3.0 / 2.0
        case .sixteenNine: return isPortrait ? 9.0 / 16.0 : 16.0 / 9.0
        }
    }
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

    @State private var previewImage: UIImage?
    @State private var imageSize: CGSize = .zero
    @State private var cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @State private var selectedRatio: AspectRatio = .free
    @State private var imageFrame: CGRect = .zero

    private var isPortrait: Bool { imageSize.height > imageSize.width }

    // Drag state
    @State private var activeHandle: HandlePosition?
    @State private var isDraggingRect = false
    @State private var dragStartRect: CGRect = .zero

    var body: some View {
        VStack(spacing: 0) {
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

            controls
        }
        .navigationTitle("Crop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
                        selectedRatio = .free
                    }
                }
            }
        }
        .onAppear {
            imageSize = ImageConverterViewModel.imageDimensions(from: fileURL) ?? .zero
            previewImage = ImageConverterViewModel.loadPreviewImage(from: fileURL)
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

            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: viewRect.width, height: viewRect.height)
                .position(x: viewRect.midX, y: viewRect.midY)

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

            ForEach(HandlePosition.allCases, id: \.rawValue) { handle in
                let pt = handle.point(in: viewRect)
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(pt)
                    .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named("cropCanvas"))
                .onChanged { value in
                    if activeHandle == nil && !isDraggingRect {
                        dragStartRect = cropRect
                        let viewRect = toViewRect(cropRect)
                        let (handle, dist) = closestHandle(to: value.startLocation)

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

        if let ratio = selectedRatio.ratio(isPortrait: isPortrait) {
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

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AspectRatio.allCases) { ratio in
                        Text(ratio.label(isPortrait: isPortrait))
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedRatio == ratio ? Color.teal : Color(.quaternarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedRatio == ratio ? .white : .primary)
                            .onTapGesture {
                                applyAspectRatio(ratio)
                            }
                    }
                }
                .padding(.horizontal, 4)
            }

            Text("\(pixelWidth) \u{00D7} \(pixelHeight)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                onApply(cropRect)
            } label: {
                Text("Apply")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding(20)
        .background(.bar)
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

    private func applyAspectRatio(_ ratio: AspectRatio) {
        selectedRatio = ratio
        guard let r = ratio.ratio(isPortrait: isPortrait) else { return }

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
