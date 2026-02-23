import SwiftUI

private enum CompressResolution: String, CaseIterable {
    case original = "Original"
    case p1080 = "1080p"
    case p720 = "720p"
    case p480 = "480p"
    case p360 = "360p"

    var height: Int? {
        switch self {
        case .original: return nil
        case .p1080: return 1080
        case .p720: return 720
        case .p480: return 480
        case .p360: return 360
        }
    }
}

private enum CompressPreset: String, CaseIterable {
    case ultrafast = "Ultrafast"
    case fast = "Fast"
    case medium = "Medium"
    case slow = "Slow"
}

private enum OutputFormat: String, CaseIterable {
    case mp4 = "MP4"
    case mov = "MOV"
    case mkv = "MKV"

    var fileExtension: String { rawValue.lowercased() }
}

struct VideoCompressView: View {
    let thumbnail: UIImage
    let fileName: String
    let fileURL: URL
    let onCompress: (_ quality: Int, _ resolutionHeight: Int?, _ preset: String, _ format: String) -> Void

    @State private var quality: Double = 8
    @State private var selectedResolution: CompressResolution = .original
    @State private var selectedPreset: CompressPreset = .medium
    @State private var selectedFormat: OutputFormat = .mp4
    @State private var originalSize: Int64 = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            preview
            Spacer()
            controls
        }
        .navigationTitle("Compress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadOriginalSize() }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 16) {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(formatBytes(originalSize))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(fileName)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            // Quality slider (mpeg4 q:v range: 1=best, 31=worst)
            VStack(spacing: 8) {
                HStack {
                    Text("Quality")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(quality))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $quality, in: 1...31, step: 1)
                HStack {
                    Text("Higher")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("Lower")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Resolution picker
            VStack(spacing: 8) {
                Text("Resolution")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                chipPicker(
                    items: CompressResolution.allCases,
                    selected: selectedResolution,
                    label: \.rawValue
                ) { selectedResolution = $0 }
            }

            // Preset picker
            VStack(spacing: 8) {
                Text("Speed")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                chipPicker(
                    items: CompressPreset.allCases,
                    selected: selectedPreset,
                    label: \.rawValue
                ) { selectedPreset = $0 }
            }

            // Output format picker
            VStack(spacing: 8) {
                Text("Format")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                chipPicker(
                    items: OutputFormat.allCases,
                    selected: selectedFormat,
                    label: \.rawValue
                ) { selectedFormat = $0 }
            }

            // Compress button
            Button {
                onCompress(
                    Int(quality),
                    selectedResolution.height,
                    selectedPreset.rawValue.lowercased(),
                    selectedFormat.fileExtension
                )
            } label: {
                Text("Compress")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(20)
        .background(.bar)
    }

    private func chipPicker<T: Hashable>(
        items: [T],
        selected: T,
        label: KeyPath<T, String>,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item[keyPath: label])
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selected == item ? Color.purple : Color(.systemGray5),
                                in: Capsule()
                            )
                            .foregroundStyle(selected == item ? .white : .primary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadOriginalSize() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64 {
            originalSize = size
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
