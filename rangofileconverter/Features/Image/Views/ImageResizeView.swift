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
    let image: UIImage
    let fileName: String
    let onApply: (UIImage, URL) -> Void

    @State private var width: Int
    @State private var height: Int
    @State private var lockAspectRatio = true
    @State private var isApplying = false
    @State private var activeField: Field?

    private let originalWidth: Int
    private let originalHeight: Int
    private var aspectRatio: Double

    private enum Field {
        case width, height
    }

    init(image: UIImage, fileName: String, onApply: @escaping (UIImage, URL) -> Void) {
        self.image = image
        self.fileName = fileName
        self.onApply = onApply
        let w = Int(image.size.width)
        let h = Int(image.size.height)
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
                    Text("Resizing...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationTitle("Resize")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    width = originalWidth
                    height = originalHeight
                }
                .disabled(isApplying || !dimensionsChanged)
            }
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Text("\(originalWidth) × \(originalHeight)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                if dimensionsChanged {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("\(width) × \(height)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)

                    let ratio = Double(width * height) / Double(originalWidth * originalHeight) * 100
                    Text(String(format: "(%.0f%%)", ratio))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            // Presets
            VStack(spacing: 8) {
                Text("Presets")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                presetPicker
            }

            // Dimensions input
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    dimensionField(label: "W", value: $width, field: .width)

                    Button {
                        lockAspectRatio.toggle()
                    } label: {
                        Image(systemName: lockAspectRatio ? "lock.fill" : "lock.open")
                            .font(.body)
                            .foregroundStyle(lockAspectRatio ? .orange : .secondary)
                            .frame(width: 36, height: 36)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }

                    dimensionField(label: "H", value: $height, field: .height)
                }
            }

            // Apply button
            Button {
                isApplying = true
                Task {
                    if let (resizedImage, url) = renderResizedImage() {
                        onApply(resizedImage, url)
                    }
                    isApplying = false
                }
            } label: {
                if isApplying {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Resize")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isApplying || !dimensionsChanged || width < 1 || height < 1)
        }
        .padding(20)
        .background(.bar)
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
                .onChange(of: value.wrappedValue) { oldValue, newValue in
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

    // MARK: - Render

    private func renderResizedImage() -> (UIImage, URL)? {
        let newSize = CGSize(width: width, height: height)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let outputName = "resized_\(UUID().uuidString.prefix(8)).\(ext)"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = resized.pngData() {
            try? data.write(to: outputURL)
            return (resized, outputURL)
        }

        return nil
    }
}
