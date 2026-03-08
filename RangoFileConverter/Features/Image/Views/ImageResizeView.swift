import SwiftUI

private enum ResizePreset: String, CaseIterable {
    case seventyFive = "75%"
    case fifty = "50%"
    case twentyFive = "25%"
    case hd = "1080p"
    case fourK = "4K"

    func apply(to size: CGSize) -> CGSize {
        switch self {
        case .seventyFive:
            return CGSize(width: round(size.width * 0.75), height: round(size.height * 0.75))
        case .fifty:
            return CGSize(width: round(size.width * 0.5), height: round(size.height * 0.5))
        case .twentyFive:
            return CGSize(width: round(size.width * 0.25), height: round(size.height * 0.25))
        case .hd:
            let longer = max(size.width, size.height)
            let scale = 1080 / longer
            if scale >= 1 { return size }
            return CGSize(width: round(size.width * scale), height: round(size.height * scale))
        case .fourK:
            let longer = max(size.width, size.height)
            let scale = 3840 / longer
            if scale >= 1 { return size }
            return CGSize(width: round(size.width * scale), height: round(size.height * scale))
        }
    }
}

struct ImageResizeView: View {
    let fileURL: URL
    let fileName: String
    let onApply: (Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewImage: UIImage?
    @State private var width: Int = 0
    @State private var height: Int = 0
    @State private var lockAspectRatio = true
    @State private var activeField: Field?
    @State private var originalSize: Int64 = 0

    private let originalWidth: Int
    private let originalHeight: Int
    private var aspectRatio: Double

    private enum Field {
        case width, height
    }

    init(fileURL: URL, fileName: String, onApply: @escaping (Int, Int) -> Void) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.onApply = onApply
        let dims = ImageConverterViewModel.imageDimensions(from: fileURL) ?? CGSize(width: 100, height: 100)
        let w = Int(dims.width)
        let h = Int(dims.height)
        self.originalWidth = w
        self.originalHeight = h
        self.aspectRatio = Double(w) / Double(h)
        self._width = State(initialValue: w)
        self._height = State(initialValue: h)
    }

    private var dimensionsChanged: Bool {
        width != originalWidth || height != originalHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            controls

            Spacer(minLength: 0)

            bottomButtons
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .onAppear {
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
            Text("Resize image")
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
            Text("\(originalWidth) \u{00D7} \(originalHeight)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            if dimensionsChanged {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textPrimary)

                Text("\(width) \u{00D7} \(height)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(-0.408)

                let ratio = Double(width * height) / Double(originalWidth * originalHeight) * 100
                Text(String(format: "(%.0f%%)", ratio))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Presets")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity, alignment: .leading)
                presetPicker
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    dimensionField(label: "W", value: $width, field: .width)

                    Button {
                        lockAspectRatio.toggle()
                    } label: {
                        Image(systemName: lockAspectRatio ? "lock.fill" : "lock.open")
                            .font(.body)
                            .foregroundColor(lockAspectRatio ? AppColors.accent : AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.textSecondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    dimensionField(label: "H", value: $height, field: .height)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let spacing: CGFloat = 8
            let resetWidth = (totalWidth - spacing) * 0.3
            let resizeWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                // Reset button (30%)
                Button {
                    width = originalWidth
                    height = originalHeight
                } label: {
                    Text("Reset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .frame(width: resetWidth, height: 60)
                        .background(AppColors.textSecondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!dimensionsChanged)
                .opacity(dimensionsChanged ? 1.0 : 0.5)

                // Resize button (70%)
                Button {
                    onApply(width, height)
                } label: {
                    Text("Resize")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: resizeWidth, height: 60)
                        .background(
                            LinearGradient(
                                colors: dimensionsChanged && width > 0 && height > 0
                                    ? [AppColors.buttonGradientStart, AppColors.buttonGradientEnd]
                                    : [AppColors.buttonDisabledStart, AppColors.buttonDisabledMid, AppColors.buttonDisabledStart],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!dimensionsChanged || width < 1 || height < 1)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 60)
        .padding(.vertical, 24)
    }

    private var presetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ResizePreset.allCases, id: \.self) { preset in
                    let targetSize = preset.apply(to: CGSize(width: originalWidth, height: originalHeight))
                    let isSelected = width == Int(targetSize.width) && height == Int(targetSize.height)
                    Button {
                        applyPreset(preset)
                    } label: {
                        Text(preset.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? Color.orange : Color(.systemGray5),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                }
            }
        }
    }

    private func dimensionField(label: String, value: Binding<Int>, field: Field) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            TextField("", value: value, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline.monospacedDigit())
                .onChange(of: value.wrappedValue) { newValue in
                    guard lockAspectRatio, newValue > 0 else { return }
                    if field == .width && activeField != .height {
                        activeField = .width
                        let newH = Int(round(Double(newValue) / aspectRatio))
                        if newH != height && newH > 0 {
                            height = newH
                        }
                        activeField = nil
                    } else if field == .height && activeField != .width {
                        activeField = .height
                        let newW = Int(round(Double(newValue) * aspectRatio))
                        if newW != width && newW > 0 {
                            width = newW
                        }
                        activeField = nil
                    }
                }
        }
    }

    private func applyPreset(_ preset: ResizePreset) {
        let original = CGSize(width: originalWidth, height: originalHeight)
        let target = preset.apply(to: original)
        activeField = .width
        width = Int(target.width)
        height = Int(target.height)
        activeField = nil
    }
}
