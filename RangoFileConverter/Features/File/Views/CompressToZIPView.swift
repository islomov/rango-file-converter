import SwiftUI
import UniformTypeIdentifiers

private struct ZIPFileItem: Identifiable {
    let id = UUID()
    let fileName: String
    let url: URL
    let fileSize: Int64
}

struct CompressToZIPView: View {
    let onCompress: ([URL], [String]) -> Void

    @State private var items: [ZIPFileItem] = []
    @State private var showFilePicker = false
    @State private var isLoadingFiles = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if items.isEmpty {
                AppColors.background
                    .ignoresSafeArea()
                emptyState
            } else {
                AppColors.background
                    .ignoresSafeArea()
                fileListState
            }

            if isLoadingFiles {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .typedFilePicker(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            emptyNavBar

            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.accent)

                    VStack(spacing: 8) {
                        Text("Add files to compress")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-0.408)
                            .multilineTextAlignment(.center)

                        Text("Any file type supported")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(-0.408)
                            .multilineTextAlignment(.center)
                    }
                }

                Button {
                    showFilePicker = true
                } label: {
                    Text("Add Files")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .padding(16)
                        .frame(width: 180)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - File List State

    private var fileListState: some View {
        VStack(spacing: 0) {
            header

            fileInfoRow

            fileList

            bottomSection
        }
    }

    // MARK: - Empty State Nav Bar

    private var emptyNavBar: some View {
        ZStack {
            Text("Compress to ZIP")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image("icon_arrow_left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .flipsForRightToLeftLayoutDirection(true)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - Header (with files)

    private var header: some View {
        ZStack {
            Text("Compress to ZIP")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.textSecondary.opacity(0.08)))
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - File Info Row

    private var fileInfoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 20))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 28, height: 28)

            Text(archiveName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)
                .lineLimit(1)

            Spacer()

            Button {
                showFilePicker = true
            } label: {
                Text("Add more")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(-0.408)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var archiveName: String {
        if items.count == 1 {
            let baseName = items[0].fileName.components(separatedBy: ".").dropLast().joined(separator: ".")
            return "\(baseName.isEmpty ? items[0].fileName : baseName).zip"
        }
        return "compressed_\(items.count)_files.zip"
    }

    private var totalOriginalBytes: Int64 {
        items.reduce(Int64(0)) { $0 + $1.fileSize }
    }

    private var totalFileSize: String {
        ByteCountFormatter.string(fromByteCount: totalOriginalBytes, countStyle: .file)
    }

    private var estimatedZIPBytes: Int64 {
        items.reduce(Int64(0)) { total, item in
            total + Self.estimatedCompressedSize(fileName: item.fileName, fileSize: item.fileSize)
        }
    }

    private var estimatedZIPSize: String {
        ByteCountFormatter.string(fromByteCount: estimatedZIPBytes, countStyle: .file)
    }

    private var savingsPercent: Int {
        guard totalOriginalBytes > 0 else { return 0 }
        let ratio = Double(totalOriginalBytes - estimatedZIPBytes) / Double(totalOriginalBytes)
        return max(0, Int(ratio * 100))
    }

    /// Estimates compressed size based on file extension heuristics.
    private static func estimatedCompressedSize(fileName: String, fileSize: Int64) -> Int64 {
        let ext = fileName.components(separatedBy: ".").last?.lowercased() ?? ""

        // Compression ratio: 1.0 = no savings, 0.3 = 70% savings
        let ratio: Double
        switch ext {
        // Already heavily compressed — almost no savings
        case "jpg", "jpeg", "heic", "webp", "jp2", "gif",
             "mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp", "ogv", "ts",
             "mp3", "aac", "ogg", "opus", "m4a", "flac", "wma", "amr", "ac3", "dts",
             "zip", "gz", "bz2", "xz", "7z", "rar", "tar.gz", "tgz",
             "jar", "apk", "ipa":
            ratio = 0.98
        // Already compressed containers (ZIP-based internally)
        case "docx", "xlsx", "pptx", "odt", "ods", "odp", "epub", "cbz":
            ratio = 0.95
        // Moderately compressible
        case "pdf", "doc", "xls", "ppt":
            ratio = 0.80
        case "png", "tiff", "tif":
            ratio = 0.85
        // Highly compressible — text-based formats
        case "txt", "html", "htm", "css", "js", "json", "xml", "csv", "rtf",
             "swift", "py", "java", "c", "cpp", "h", "md", "yaml", "yml", "log", "svg":
            ratio = 0.35
        // Uncompressed media — very compressible
        case "bmp", "raw", "wav", "aiff", "au", "ppm", "pgm", "pbm", "tga",
             "exr", "pfm", "ras", "rgb", "sgi", "xwd", "yuv", "w64", "snd", "caf":
            ratio = 0.40
        // Unknown — moderate estimate
        default:
            ratio = 0.75
        }

        return Int64(Double(fileSize) * ratio)
    }

    // MARK: - File List

    private var fileList: some View {
        List {
            ForEach(items) { item in
                HStack(spacing: 12) {
                    fileExtensionBadge(for: item.fileName)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.fileName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-0.408)
                            .lineLimit(1)

                        Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(-0.408)
                    }

                    Spacer()
                }
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
                        .frame(height: 1)
                }
            }
            .onDelete { offsets in
                items.remove(atOffsets: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func fileExtensionBadge(for fileName: String) -> some View {
        let ext = fileName.components(separatedBy: ".").last?.uppercased() ?? "FILE"
        return Text(ext)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 52, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8.32)
                    .fill(AppColors.accent.opacity(0.8))
            )
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Original:")
                            .foregroundColor(AppColors.textSecondary)
                        Text(totalFileSize)
                            .foregroundColor(AppColors.textPrimary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                        Text("~\(estimatedZIPSize)")
                            .foregroundColor(AppColors.accent)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.408)

                    if savingsPercent > 0 {
                        Text("Estimated ~\(savingsPercent)% smaller")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(-0.408)
                    }
                }

                Button {
                    onCompress(items.map(\.url), items.map(\.fileName))
                } label: {
                    Text(items.count == 1 ? "Compress \(items.count) File" : "Compress \(items.count) Files")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(compressButtonGradient)
                        )
                }
                .disabled(items.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    private var compressButtonGradient: LinearGradient {
        if items.isEmpty {
            return LinearGradient(
                colors: [AppColors.buttonDisabledStart, AppColors.buttonDisabledMid, AppColors.buttonDisabledStart],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        } else {
            return LinearGradient(
                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        isLoadingFiles = true
        var accessedURLs: [(URL, String)] = []
        for sourceURL in urls {
            if sourceURL.startAccessingSecurityScopedResource() {
                accessedURLs.append((sourceURL, sourceURL.lastPathComponent))
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("rango_zip_compress", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            var newItems: [ZIPFileItem] = []
            for (sourceURL, fileName) in accessedURLs {
                let shortID = UUID().uuidString.prefix(8)
                let destURL = tempDir.appendingPathComponent("\(shortID)_\(fileName)")
                try? FileManager.default.removeItem(at: destURL)

                if let _ = try? FileManager.default.copyItem(at: sourceURL, to: destURL) {
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
                    newItems.append(ZIPFileItem(fileName: fileName, url: destURL, fileSize: fileSize))
                }
                sourceURL.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                items.append(contentsOf: newItems)
                isLoadingFiles = false
            }
        }
    }
}
