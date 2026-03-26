import SwiftUI
import PencilKit

// MARK: - Drawing Tool Types

private enum DrawingToolType: String, CaseIterable, Identifiable {
    case pen = "Pen"
    case marker = "Marker"
    case pencil = "Pencil"
    case eraser = "Eraser"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .pencil: return "pencil"
        case .eraser: return "eraser"
        }
    }
}

// MARK: - Preset Colors

private let presetColors: [Color] = [
    .white, .black,
    .red, .orange, .yellow,
    .green, .blue, .purple,
    .pink, .brown, .cyan, .gray
]

// MARK: - Canvas UIViewRepresentable

private struct DrawingCanvasView: UIViewRepresentable {
    let image: UIImage
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .white, width: 5)
        canvasView.becomeFirstResponder()
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

// MARK: - ImageDrawView

struct ImageDrawView: View {
    let fileURL: URL
    let fileName: String
    let onApply: (PKDrawing, CGSize) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewImage: UIImage?
    @State private var imageSize: CGSize = .zero
    @State private var canvasView = PKCanvasView()

    // Drawing customization
    @State private var selectedTool: DrawingToolType = .pen
    @State private var selectedColor: Color = .white
    @State private var lineWidth: CGFloat = 5
    @State private var showColorPicker = false

    private var hasDrawing: Bool {
        !canvasView.drawing.strokes.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            canvasSection

            controlsSection

            Spacer(minLength: 0)

            bottomButtons
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .onAppear {
            imageSize = ImageConverterViewModel.imageDimensions(from: fileURL) ?? .zero
            previewImage = ImageConverterViewModel.loadPreviewImage(from: fileURL)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Draw")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Spacer()

                // Undo / Redo
                HStack(spacing: 12) {
                    Button {
                        canvasView.undoManager?.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Button {
                        canvasView.undoManager?.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                Spacer().frame(width: 12)

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

    // MARK: - Canvas Section

    private var canvasSection: some View {
        GeometryReader { geo in
            let fittedRect = Self.aspectFitRect(
                imageSize: imageSize,
                in: CGSize(width: geo.size.width, height: geo.size.height)
            )
            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)

                    DrawingCanvasView(image: previewImage, canvasView: $canvasView)
                        .frame(width: fittedRect.width, height: fittedRect.height)
                } else {
                    ProgressView()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 320)
        .padding(.horizontal, 16)
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Tool picker
            toolPicker

            // Line width slider
            lineWidthControl

            // Color palette
            colorPalette
        }
        .padding(16)
    }

    private var toolPicker: some View {
        HStack(spacing: 8) {
            ForEach(DrawingToolType.allCases) { tool in
                Button {
                    selectedTool = tool
                    applyTool()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.systemIcon)
                            .font(.system(size: 18))
                            .foregroundColor(
                                selectedTool == tool ? .white : AppColors.textPrimary
                            )

                        Text(LocalizedStringKey(tool.rawValue))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(
                                selectedTool == tool ? .white : AppColors.textPrimary
                            )
                            .tracking(-0.408)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        selectedTool == tool
                            ? AppColors.accent
                            : AppColors.textSecondary.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var lineWidthControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Brush size")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                Spacer()

                Text(String(format: "%.0f", lineWidth))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-0.408)
            }

            HStack(spacing: 12) {
                // Min dot
                Circle()
                    .fill(AppColors.textPrimary)
                    .frame(width: 4, height: 4)

                Slider(value: $lineWidth, in: 1...30, step: 1)
                    .accentColor(AppColors.accent)
                    .onChange(of: lineWidth) { _ in
                        applyTool()
                    }

                // Max dot
                Circle()
                    .fill(AppColors.textPrimary)
                    .frame(width: 16, height: 16)
            }
        }
    }

    private var colorPalette: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(-0.408)

            HStack(spacing: 8) {
                ForEach(Array(presetColors.enumerated()), id: \.offset) { _, color in
                    Button {
                        selectedColor = color
                        if selectedTool == .eraser {
                            selectedTool = .pen
                        }
                        applyTool()
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(
                                        AppColors.border,
                                        lineWidth: 1
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppColors.accent, lineWidth: 2.5)
                                    .padding(-2)
                                    .opacity(selectedColor == color && selectedTool != .eraser ? 1 : 0)
                            )
                    }
                }
            }
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let spacing: CGFloat = 8
            let clearWidth = (totalWidth - spacing) * 0.3
            let applyWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                Button {
                    canvasView.drawing = PKDrawing()
                } label: {
                    Text("Clear")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .frame(width: clearWidth, height: 60)
                        .background(AppColors.textSecondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    onApply(canvasView.drawing, canvasView.bounds.size)
                } label: {
                    Text("Apply drawing")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: applyWidth, height: 60)
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

    // MARK: - Aspect Fit Helper

    private static func aspectFitRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        let fittedWidth = imageSize.width * scale
        let fittedHeight = imageSize.height * scale
        let x = (containerSize.width - fittedWidth) / 2
        let y = (containerSize.height - fittedHeight) / 2
        return CGRect(x: x, y: y, width: fittedWidth, height: fittedHeight)
    }

    // MARK: - Apply Tool to Canvas

    private func applyTool() {
        let uiColor = UIColor(selectedColor)

        switch selectedTool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: lineWidth)
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: uiColor, width: lineWidth)
        case .pencil:
            canvasView.tool = PKInkingTool(.pencil, color: uiColor, width: lineWidth)
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap)
        }
    }
}
