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

    @Environment(\.dismiss) private var dismiss
    @State private var quality: Double = 8
    @State private var selectedResolution: CompressResolution = .original
    @State private var selectedPreset: CompressPreset = .medium
    @State private var selectedFormat: OutputFormat = .mp4
    @State private var originalSize: Int64 = 0

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            ScrollView {
                controlsSection
            }

            Spacer(minLength: 0)

            bottomButton
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .onAppear { loadOriginalSize() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Compress video")
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

            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 24)

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
        Text(formatBytes(originalSize))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppColors.textSecondary)
            .tracking(-0.408)
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quality
            VStack(spacing: 12) {
                HStack {
                    Text("Quality")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                    Spacer()
                    Text("\(Int(quality))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }

                Slider(value: $quality, in: 1...31, step: 1)
                    .tint(AppColors.accent)
            }

            // Resolution
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                chipPicker(
                    items: CompressResolution.allCases,
                    selected: selectedResolution,
                    label: \.rawValue
                ) { selectedResolution = $0 }
            }

            // Speed
            VStack(alignment: .leading, spacing: 8) {
                Text("Speed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                chipPicker(
                    items: CompressPreset.allCases,
                    selected: selectedPreset,
                    label: \.rawValue
                ) { selectedPreset = $0 }
            }

            // Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                chipPicker(
                    items: OutputFormat.allCases,
                    selected: selectedFormat,
                    label: \.rawValue
                ) { selectedFormat = $0 }
            }
        }
        .padding(16)
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
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.408)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selected == item
                                    ? AppColors.accent
                                    : AppColors.textSecondary.opacity(0.08),
                                in: Capsule()
                            )
                            .foregroundColor(selected == item ? .white : AppColors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Button {
                onCompress(
                    Int(quality),
                    selectedResolution.height,
                    selectedPreset.rawValue.lowercased(),
                    selectedFormat.fileExtension
                )
            } label: {
                Text("Compress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private func loadOriginalSize() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64 {
            originalSize = size
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "\u{2014}" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
