import SwiftUI

struct ImageRotateView: View {
    let fileURL: URL
    let fileName: String
    let onApply: (Double, Bool, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rotation: Double = 0
    @State private var flipH = false
    @State private var flipV = false
    @State private var previewImage: UIImage?
    @State private var originalSize: Int64 = 0
    @State private var estimatedSize: Int64 = 0

    var body: some View {
        VStack(spacing: 0) {
            // Image preview area
            previewSection

            // Controls
            controlsSection

            Spacer(minLength: 0)

            // Bottom button
            bottomButton
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .onAppear {
            previewImage = ImageConverterViewModel.loadPreviewImage(from: fileURL)
            loadOriginalSize()
            updateEstimatedSize()
        }
        .onChange(of: rotation) { _ in
            updateEstimatedSize()
        }
        .onChange(of: flipH) { _ in
            updateEstimatedSize()
        }
        .onChange(of: flipV) { _ in
            updateEstimatedSize()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Rotate image")
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

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
                    .animation(.easeInOut(duration: 0.25), value: rotation)
                    .animation(.easeInOut(duration: 0.25), value: flipH)
                    .animation(.easeInOut(duration: 0.25), value: flipV)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                ProgressView()
                    .frame(height: 260)
                    .padding(.vertical, 24)
            }

            // File size info
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
            Text(formatBytes(originalSize))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textPrimary)

            Text(formatBytes(estimatedSize))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.accent)
                .tracking(-0.408)

            if originalSize > 0 && estimatedSize > 0 {
                let ratio = Double(estimatedSize) / Double(originalSize) * 100
                Text(String(format: "(%.0f%%)", ratio))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)
            }
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Rotate buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Rotate")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                HStack(spacing: 0) {
                    rotateButton(icon: "rotate.left", action: { rotation -= 90 })
                    Spacer()
                    rotateButton(icon: "rotate.right", action: { rotation += 90 })
                    Spacer()
                    rotateButton(
                        icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                        action: { flipH.toggle() }
                    )
                    Spacer()
                    rotateButton(
                        icon: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                        action: { flipV.toggle() }
                    )
                }
            }

            // Degree slider
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text("\(Int(normalizedDegrees))\u{00B0}")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                    Spacer()
                }

                Slider(value: $rotation, in: -180...180, step: 1)
                    .tint(AppColors.accent)
            }
        }
        .padding(16)
    }

    private func rotateButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 72, height: 72)
                .background(AppColors.textSecondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Bottom Buttons

    private var hasChanges: Bool {
        rotation != 0 || flipH || flipV
    }

    private var bottomButton: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32 // 16px padding on each side
            let spacing: CGFloat = 8
            let resetWidth = (totalWidth - spacing) * 0.3
            let rotateWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                // Reset button (30%)
                Button {
                    rotation = 0
                    flipH = false
                    flipV = false
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

                // Rotate button (70%)
                Button {
                    onApply(rotation, flipH, flipV)
                } label: {
                    Text("Rotate")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: rotateWidth, height: 60)
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

    // MARK: - Helpers

    private var normalizedDegrees: Double {
        let mod = rotation.truncatingRemainder(dividingBy: 360)
        return mod < 0 ? mod + 360 : mod
    }

    private func loadOriginalSize() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64 {
            originalSize = size
        }
    }

    private func updateEstimatedSize() {
        if rotation == 0 && !flipH && !flipV {
            estimatedSize = originalSize
        } else {
            let multiplier: Double = 1.05
            estimatedSize = Int64(Double(originalSize) * multiplier)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "\u{2014}" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
