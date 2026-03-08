import SwiftUI

struct ImageDetailView: View {
    let fileURL: URL
    let fileName: String
    let onConvert: (FormatDefinition) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewImage: UIImage?
    @State private var targetFormat: FormatDefinition = FormatRegistry.imageFormats[1] // JPEG
    @State private var originalSize: Int64 = 0

    private let formatColumns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        VStack(spacing: 0) {
            previewSection

            ScrollView {
                formatSelection
            }

            bottomButton
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .onAppear {
            previewImage = ImageConverterViewModel.loadPreviewImage(from: fileURL)
            loadOriginalSize()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Convert image")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(hex: "888888").opacity(0.08))
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "E6E6EC"))
                    .frame(width: 200, height: 260)
                    .padding(.vertical, 24)
            }

            fileSizeInfo
                .padding(.bottom, 12)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var fileSizeInfo: some View {
        HStack(spacing: 4) {
            Text(formatBytes(originalSize))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)
        }
    }

    // MARK: - Format Selection

    private var formatSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Convert to")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "888888"))
                .tracking(-0.408)

            LazyVGrid(columns: formatColumns, spacing: 4) {
                ForEach(FormatRegistry.imageFormats) { format in
                    Button {
                        targetFormat = format
                    } label: {
                        Text(format.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(-0.408)
                            .foregroundColor(
                                targetFormat.id == format.id
                                    ? Color(hex: "F4800D")
                                    : Color(hex: "1D1D1D")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        targetFormat.id == format.id
                                            ? Color(hex: "F4800D").opacity(0.08)
                                            : Color.clear
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32 // 16px padding on each side
            let spacing: CGFloat = 8
            let resetWidth = (totalWidth - spacing) * 0.3
            let convertWidth = (totalWidth - spacing) * 0.7

            HStack(spacing: spacing) {
                // Reset button (30%)
                Button {
                    targetFormat = FormatRegistry.imageFormats[1] // Reset to JPEG
                } label: {
                    Text("Reset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .tracking(-0.408)
                        .frame(width: resetWidth, height: 60)
                        .background(Color(hex: "888888").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Convert button (70%)
                Button {
                    onConvert(targetFormat)
                } label: {
                    Text("Convert")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(width: convertWidth, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FFA05C"), Color(hex: "EF731A")],
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
