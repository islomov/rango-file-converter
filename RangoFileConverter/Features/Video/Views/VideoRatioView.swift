import SwiftUI
import AVFoundation

private enum VideoAspectRatio: String, CaseIterable, Identifiable {
    case r16_9 = "16:9"
    case r9_16 = "9:16"
    case r4_3 = "4:3"
    case r3_4 = "3:4"
    case r1_1 = "1:1"
    case r21_9 = "21:9"

    var id: String { rawValue }

    var width: Int {
        switch self {
        case .r16_9: return 16
        case .r9_16: return 9
        case .r4_3: return 4
        case .r3_4: return 3
        case .r1_1: return 1
        case .r21_9: return 21
        }
    }

    var height: Int {
        switch self {
        case .r16_9: return 9
        case .r9_16: return 16
        case .r4_3: return 3
        case .r3_4: return 4
        case .r1_1: return 1
        case .r21_9: return 9
        }
    }

    var ratio: CGFloat {
        CGFloat(width) / CGFloat(height)
    }

    /// Visual rectangle proportions for the ratio card icon (width, height) normalized
    var iconProportions: (width: CGFloat, height: CGFloat) {
        switch self {
        case .r16_9: return (45, 27)
        case .r9_16: return (24, 36)
        case .r4_3: return (24, 35)
        case .r3_4: return (35, 24)
        case .r1_1: return (24, 24)
        case .r21_9: return (32, 24)
        }
    }
}

struct VideoRatioView: View {
    let thumbnail: UIImage
    let fileName: String
    let fileURL: URL
    let onApply: (_ aspectRatio: (width: Int, height: Int), _ fitMode: RatioFitMode, _ cropPosition: CGPoint?, _ cropScale: CGFloat?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRatio: VideoAspectRatio = .r16_9
    @State private var fitMode: RatioFitMode = .crop
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var isPlaying = false
    @State private var videoAspectRatio: CGFloat?

    // Crop position: normalized 0...1 (0.5 = centered)
    @State private var cropPositionX: CGFloat = 0.5
    @State private var cropPositionY: CGFloat = 0.5

    // Crop scale: 0.3...1.0 (1.0 = max size that fits in video)
    @State private var cropScale: CGFloat = 1.0

    // Gesture tracking
    @GestureState private var moveDrag: CGSize = .zero
    @GestureState private var resizeDrag: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            ScrollView {
                controlsSection
            }

            Spacer(minLength: 0)

            bottomButtons
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .task {
            await setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: selectedRatio) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                cropPositionX = 0.5
                cropPositionY = 0.5
                cropScale = 1.0
            }
        }
        .onChange(of: fitMode) { _ in
            cropPositionX = 0.5
            cropPositionY = 0.5
            cropScale = 1.0
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Video ratio")
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
                let availableSize = geo.size
                let videoRatio = videoAspectRatio ?? (thumbnail.size.width / thumbnail.size.height)
                let videoDisplaySize = aspectFitSize(ratio: videoRatio, in: availableSize)

                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 0)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.placeholder, AppColors.placeholder],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .shadow(.inner(color: .black.opacity(0.08), radius: 0, x: 0, y: 0))
                        )

                    // Video layer
                    if let player {
                        PlayerView(player: player)
                            .frame(width: videoDisplaySize.width, height: videoDisplaySize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: videoDisplaySize.width, height: videoDisplaySize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Interactive overlay
                    if fitMode == .crop {
                        cropOverlay(videoSize: videoDisplaySize)
                    } else {
                        padOverlay(videoSize: videoDisplaySize, videoRatio: videoRatio)
                    }

                }
                .frame(width: availableSize.width, height: availableSize.height)
            }
            .frame(height: 341)
            .overlay(alignment: .bottomTrailing) {
                if player != nil {
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(8)
                }
            }
        }
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Crop Overlay

    private func cropOverlay(videoSize: CGSize) -> some View {
        let targetRatio = selectedRatio.ratio
        let maxCropSize = cropFitSize(targetRatio: targetRatio, in: videoSize)

        // Apply scale + active resize drag
        let effectiveScale = clampScale(cropScale + resizeDrag)
        let cropW = maxCropSize.width * effectiveScale
        let cropH = maxCropSize.height * effectiveScale

        // Clamp position so crop stays within video
        let maxTravelX = max(0, videoSize.width - cropW)
        let maxTravelY = max(0, videoSize.height - cropH)

        // Apply move drag (convert from points to normalized)
        let dragNormX = maxTravelX > 0 ? moveDrag.width / maxTravelX : 0
        let dragNormY = maxTravelY > 0 ? moveDrag.height / maxTravelY : 0
        let posX = clamp(cropPositionX + dragNormX, 0, 1)
        let posY = clamp(cropPositionY + dragNormY, 0, 1)

        let offsetX = (posX - 0.5) * maxTravelX
        let offsetY = (posY - 0.5) * maxTravelY

        let cropSize = CGSize(width: cropW, height: cropH)

        return ZStack {
            // Dim area outside the crop
            Rectangle()
                .fill(.black.opacity(0.45))
                .mask {
                    Rectangle()
                        .overlay {
                            Rectangle()
                                .frame(width: cropW, height: cropH)
                                .offset(x: offsetX, y: offsetY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .frame(width: videoSize.width, height: videoSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)

            // Crop frame — draggable to move
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())

                Rectangle()
                    .stroke(.white, lineWidth: 2)

                gridLines(size: cropSize)

                VStack {
                    Spacer()
                    HStack {
                        Text(selectedRatio.rawValue)
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(4)
                        Spacer()
                    }
                }
            }
            .frame(width: cropW, height: cropH)
            .offset(x: offsetX, y: offsetY)
            .gesture(moveGesture(maxTravelX: maxTravelX, maxTravelY: maxTravelY))

            // Corner resize handles
            ForEach(0..<4, id: \.self) { corner in
                resizeHandle(
                    corner: corner,
                    cropSize: cropSize,
                    offset: CGPoint(x: offsetX, y: offsetY),
                    maxCropSize: maxCropSize
                )
            }

            // Edge resize handles (mid-points)
            ForEach(0..<4, id: \.self) { edge in
                edgeHandle(
                    edge: edge,
                    cropSize: cropSize,
                    offset: CGPoint(x: offsetX, y: offsetY),
                    maxCropSize: maxCropSize
                )
            }
        }
    }

    // MARK: - Move Gesture

    private func moveGesture(maxTravelX: CGFloat, maxTravelY: CGFloat) -> some Gesture {
        DragGesture()
            .updating($moveDrag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let dragNormX = maxTravelX > 0 ? value.translation.width / maxTravelX : 0
                let dragNormY = maxTravelY > 0 ? value.translation.height / maxTravelY : 0
                cropPositionX = clamp(cropPositionX + dragNormX, 0, 1)
                cropPositionY = clamp(cropPositionY + dragNormY, 0, 1)
            }
    }

    // MARK: - Resize Handles

    private func resizeHandle(corner: Int, cropSize: CGSize, offset: CGPoint, maxCropSize: CGSize) -> some View {
        let handleSize: CGFloat = 44
        let visualSize: CGFloat = 20

        let xSign: CGFloat = (corner == 0 || corner == 3) ? -1 : 1
        let ySign: CGFloat = (corner == 0 || corner == 1) ? -1 : 1

        let handleX = offset.x + xSign * cropSize.width / 2
        let handleY = offset.y + ySign * cropSize.height / 2

        return ZStack {
            CornerBracketShape()
                .stroke(.white, lineWidth: 3)
                .frame(width: visualSize, height: visualSize)
                .rotationEffect(.degrees(Double(corner) * 90))
        }
        .frame(width: handleSize, height: handleSize)
        .contentShape(Rectangle())
        .offset(x: handleX, y: handleY)
        .gesture(resizeGesture(maxCropSize: maxCropSize, xSign: xSign, ySign: ySign))
    }

    private func edgeHandle(edge: Int, cropSize: CGSize, offset: CGPoint, maxCropSize: CGSize) -> some View {
        let handleSize: CGFloat = 44
        let barLength: CGFloat = 24
        let barThickness: CGFloat = 3

        let isVertical = edge == 0 || edge == 2
        let xSign: CGFloat = edge == 1 ? 1 : (edge == 3 ? -1 : 0)
        let ySign: CGFloat = edge == 2 ? 1 : (edge == 0 ? -1 : 0)

        let handleX = offset.x + xSign * cropSize.width / 2
        let handleY = offset.y + ySign * cropSize.height / 2

        return ZStack {
            RoundedRectangle(cornerRadius: barThickness / 2)
                .fill(.white)
                .frame(
                    width: isVertical ? barLength : barThickness,
                    height: isVertical ? barThickness : barLength
                )
        }
        .frame(width: handleSize, height: handleSize)
        .contentShape(Rectangle())
        .offset(x: handleX, y: handleY)
        .gesture(resizeGesture(maxCropSize: maxCropSize, xSign: xSign, ySign: ySign))
    }

    private func resizeGesture(maxCropSize: CGSize, xSign: CGFloat, ySign: CGFloat) -> some Gesture {
        DragGesture()
            .updating($resizeDrag) { value, state, _ in
                let outward = value.translation.width * xSign + value.translation.height * ySign
                let refDim = max(maxCropSize.width, maxCropSize.height)
                state = outward / refDim
            }
            .onEnded { value in
                let outward = value.translation.width * xSign + value.translation.height * ySign
                let refDim = max(maxCropSize.width, maxCropSize.height)
                let delta = outward / refDim
                cropScale = clampScale(cropScale + delta)
                reclampPosition()
            }
    }

    // MARK: - Pad Overlay

    private func padOverlay(videoSize: CGSize, videoRatio: CGFloat) -> some View {
        let targetRatio = selectedRatio.ratio
        let padFrameSize = aspectFitSize(ratio: targetRatio, in: videoSize)
        let videoInPad = aspectFitSize(ratio: videoRatio, in: padFrameSize)

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .frame(width: padFrameSize.width, height: padFrameSize.height)

            RoundedRectangle(cornerRadius: 2)
                .stroke(.white, lineWidth: 2)
                .frame(width: videoInPad.width, height: videoInPad.height)

            if padFrameSize.width > videoInPad.width + 2 {
                let barWidth = (padFrameSize.width - videoInPad.width) / 2
                HStack(spacing: 0) {
                    Rectangle().fill(.black.opacity(0.5)).frame(width: barWidth, height: padFrameSize.height)
                    Spacer()
                    Rectangle().fill(.black.opacity(0.5)).frame(width: barWidth, height: padFrameSize.height)
                }
                .frame(width: padFrameSize.width, height: padFrameSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if padFrameSize.height > videoInPad.height + 2 {
                let barHeight = (padFrameSize.height - videoInPad.height) / 2
                VStack(spacing: 0) {
                    Rectangle().fill(.black.opacity(0.5)).frame(width: padFrameSize.width, height: barHeight)
                    Spacer()
                    Rectangle().fill(.black.opacity(0.5)).frame(width: padFrameSize.width, height: barHeight)
                }
                .frame(width: padFrameSize.width, height: padFrameSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack {
                Spacer()
                HStack {
                    Text(selectedRatio.rawValue)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(6)
                    Spacer()
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Grid Lines

    private func gridLines(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let color = Color.white.opacity(0.3)
            for i in 1...2 {
                let x = canvasSize.width * CGFloat(i) / 3
                var vPath = Path()
                vPath.move(to: CGPoint(x: x, y: 0))
                vPath.addLine(to: CGPoint(x: x, y: canvasSize.height))
                context.stroke(vPath, with: .color(color), lineWidth: 0.5)
            }
            for i in 1...2 {
                let y = canvasSize.height * CGFloat(i) / 3
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: y))
                hPath.addLine(to: CGPoint(x: canvasSize.width, y: y))
                context.stroke(hPath, with: .color(color), lineWidth: 0.5)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Ratio grid
            ratioGrid

            // Fit mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Fit mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                HStack(spacing: 8) {
                    ForEach(RatioFitMode.allCases, id: \.self) { mode in
                        Button {
                            fitMode = mode
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .tracking(-0.408)
                                .foregroundColor(
                                    fitMode == mode ? .white : AppColors.textPrimary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(
                                            fitMode == mode
                                                ? AppColors.accent
                                                : AppColors.textSecondary.opacity(0.08)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Ratio Grid

    private var ratioGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(VideoAspectRatio.allCases) { ratio in
                Button {
                    selectedRatio = ratio
                } label: {
                    ratioCard(ratio: ratio, isSelected: selectedRatio == ratio)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func ratioCard(ratio: VideoAspectRatio, isSelected: Bool) -> some View {
        let props = ratio.iconProportions

        return VStack {
            ZStack {
                // Rectangle shape representing the ratio
                RoundedRectangle(cornerRadius: 3)
                    .stroke(AppColors.textPrimary, lineWidth: 1.5)
                    .frame(width: props.width, height: props.height)

                // Ratio text
                Text(ratio.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-0.3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isSelected
                        ? AppColors.accent.opacity(0.08)
                        : AppColors.textSecondary.opacity(0.12)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ? AppColors.accentLight : .clear,
                    lineWidth: 2
                )
        )
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let spacing: CGFloat = 12
            let resetWidth = (totalWidth - spacing) * 0.3
            let convertWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        cropPositionX = 0.5
                        cropPositionY = 0.5
                        cropScale = 1.0
                    }
                } label: {
                    Text("Reset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .frame(width: resetWidth, height: 60)
                        .background(AppColors.textSecondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    player?.pause()
                    isPlaying = false
                    let position: CGPoint? = fitMode == .crop ? CGPoint(x: cropPositionX, y: cropPositionY) : nil
                    let scale: CGFloat? = fitMode == .crop ? cropScale : nil
                    onApply((width: selectedRatio.width, height: selectedRatio.height), fitMode, position, scale)
                } label: {
                    Text("Apply ratio")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: convertWidth, height: 60)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(player == nil)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 60)
        .padding(.vertical, 24)
    }

    // MARK: - Player

    private func setupPlayer() async {
        let asset = AVAsset(url: fileURL)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = tracks.first {
                let size = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let transformedSize = size.applying(transform)
                let w = abs(transformedSize.width)
                let h = abs(transformedSize.height)
                if w > 0 && h > 0 {
                    videoAspectRatio = w / h
                }
            }
        } catch {
            return
        }

        let playerItem = AVPlayerItem(url: fileURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.actionAtItemEnd = .pause

        let observer = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak avPlayer] time in
            guard let avPlayer else { return }
            if isPlaying, let duration = avPlayer.currentItem?.duration.seconds, duration > 0 {
                let current = CMTimeGetSeconds(time)
                if current.isFinite && duration.isFinite && current >= duration - 0.1 {
                    isPlaying = false
                }
            }
        }

        timeObserver = observer
        player = avPlayer
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            let current = CMTimeGetSeconds(player.currentTime())
            let total = player.currentItem?.duration.seconds ?? 0
            if current.isFinite && total.isFinite && current >= total - 0.2 {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    player.play()
                    isPlaying = true
                }
            } else {
                player.play()
                isPlaying = true
            }
        }
    }

    private func cleanupPlayer() {
        player?.pause()
        isPlaying = false
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player = nil
    }

    // MARK: - Helpers

    private func aspectFitSize(ratio: CGFloat, in container: CGSize) -> CGSize {
        let containerRatio = container.width / container.height
        if ratio > containerRatio {
            return CGSize(width: container.width, height: container.width / ratio)
        } else {
            return CGSize(width: container.height * ratio, height: container.height)
        }
    }

    private func cropFitSize(targetRatio: CGFloat, in videoSize: CGSize) -> CGSize {
        let videoRatio = videoSize.width / videoSize.height
        if targetRatio > videoRatio {
            return CGSize(width: videoSize.width, height: videoSize.width / targetRatio)
        } else {
            return CGSize(width: videoSize.height * targetRatio, height: videoSize.height)
        }
    }

    private func clampScale(_ s: CGFloat) -> CGFloat {
        min(1.0, max(0.3, s))
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(hi, max(lo, v))
    }

    private func reclampPosition() {
        cropPositionX = clamp(cropPositionX, 0, 1)
        cropPositionY = clamp(cropPositionY, 0, 1)
    }
}

// MARK: - Corner Bracket Shape

private struct CornerBracketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.5))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY))
        return p
    }
}
