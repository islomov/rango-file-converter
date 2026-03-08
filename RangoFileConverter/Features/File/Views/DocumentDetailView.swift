import SwiftUI

struct DocumentDetailView: View {
    let fileName: String
    let fileURL: URL
    let onConvert: (FormatDefinition) -> Void

    private static let supportedFormats = FormatRegistry.documentFormats

    @Environment(\.dismiss) private var dismiss
    @State private var targetFormat: FormatDefinition = FormatRegistry.documentFormats[0]
    @State private var fileSizeText: String = ""

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

            Spacer()

            bottomButton
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .task {
            let path = fileURL.path
            let size = await Task.detached(priority: .utility) {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let bytes = attrs[.size] as? Int64 else { return "" }
                return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }.value
            fileSizeText = size
        }
        .onAppear {
            if let first = availableFormats.first {
                targetFormat = first
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Convert document")
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

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.placeholder)
                    .frame(height: 180)

                VStack(spacing: 12) {
                    Image(systemName: documentIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)

                    Text(sourceExtension.uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.textSecondary.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // File info
            VStack(spacing: 4) {
                Text(fileName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-0.408)
                    .lineLimit(1)

                if !fileSizeText.isEmpty {
                    Text(fileSizeText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }
            }
            .padding(.bottom, 16)
        }
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Format Selection

    private var formatSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Convert to")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(-0.408)

            LazyVGrid(columns: formatColumns, spacing: 4) {
                ForEach(availableFormats) { format in
                    Button {
                        targetFormat = format
                    } label: {
                        Text(format.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(-0.408)
                            .foregroundColor(
                                targetFormat.id == format.id
                                    ? AppColors.accent
                                    : AppColors.textPrimary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        targetFormat.id == format.id
                                            ? AppColors.accent.opacity(0.08)
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
        Button {
            onConvert(targetFormat)
        } label: {
            Text("Convert")
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
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private var availableFormats: [FormatDefinition] {
        Self.supportedFormats.filter { $0.fileExtension.lowercased() != sourceExtension.lowercased() }
    }

    private var sourceExtension: String {
        fileName.components(separatedBy: ".").last ?? ""
    }

    private var documentIcon: String {
        switch sourceExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "html": return "globe"
        case "rtf": return "doc.richtext"
        case "txt": return "doc.plaintext"
        case "odt": return "doc.text"
        default: return "doc"
        }
    }
}
