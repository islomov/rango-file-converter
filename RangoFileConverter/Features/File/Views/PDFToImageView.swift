import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFToImageView: View {
    let onConvert: (URL, String, FormatDefinition, [Int]) -> Void

    private static let supportedFormats: [FormatDefinition] = FormatRegistry.imageFormats.filter {
        ["jpeg", "png", "jpg", "heic", "bmp", "tiff"].contains($0.fileExtension.lowercased())
    }

    @State private var fileURL: URL?
    @State private var fileName: String = ""
    @State private var pageCount: Int = 0
    @State private var selectedPages: [Int: Bool] = [:]
    @State private var pageThumbnails: [Int: UIImage] = [:]
    @State private var targetFormat: FormatDefinition = supportedFormats[0]
    @State private var showFilePicker = false
    @State private var isLoadingPDF = false
    @Environment(\.dismiss) private var dismiss

    private var selectedCount: Int {
        selectedPages.values.filter { $0 }.count
    }

    private var allSelected: Bool {
        pageCount > 0 && selectedCount == pageCount
    }

    private let formatColumns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            if fileURL == nil {
                emptyState
            } else {
                detailState
            }

            if isLoadingPDF {
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
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            navBar

            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.accent)

                    Text("Select a PDF to convert to images")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showFilePicker = true
                } label: {
                    Text("Choose PDF")
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

    // MARK: - Detail State

    private var detailState: some View {
        VStack(spacing: 0) {
            navBar
                .background(AppColors.surface)

            fileInfoRow

            formatSelection

            pageSelectionHeader

            ScrollView {
                let columns = [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                ]

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        pageCell(index: index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .padding(.top, 4)

            convertButton
        }
    }

    // MARK: - File Info Row

    private var fileInfoRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.placeholder)
                    .frame(width: 28, height: 28)

                Image(systemName: "doc.richtext")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-0.408)
                    .lineLimit(1)

                Text("\(pageCount) pages")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)
            }

            Spacer()

            Button {
                showFilePicker = true
            } label: {
                Text("Change")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(-0.408)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.12))
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
                ForEach(Self.supportedFormats) { format in
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

    // MARK: - Page Selection Header

    private var pageSelectionHeader: some View {
        HStack {
            Text("Select pages to convert")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(-0.408)

            Spacer()

            Group {
                if allSelected {
                    Text("Deselect all")
                } else {
                    Text("Select all")
                }
            }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.accent)
                .tracking(-0.408)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelectAll()
                }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func toggleSelectAll() {
        if allSelected {
            selectedPages = [:]
        } else {
            var updated: [Int: Bool] = [:]
            for i in 0..<pageCount {
                updated[i] = true
            }
            selectedPages = updated
        }
    }

    // MARK: - Page Cell

    private func pageCell(index: Int) -> some View {
        let isSelected = selectedPages[index] == true

        return Button {
            selectedPages[index] = !isSelected
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail = pageThumbnails[index] {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .background(AppColors.placeholder)
                } else {
                    Rectangle()
                        .fill(AppColors.placeholder)
                        .frame(height: 140)
                }

                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.accent : Color.white)
                    )
                    .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? AppColors.accent : Color.clear,
                        lineWidth: 2.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Convert Button

    private var convertButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)

            Button {
                performConvert()
            } label: {
                Group {
                    if selectedCount == 0 {
                        Text("Convert to \(targetFormat.displayName)")
                    } else {
                        Text("Convert \(selectedCount) pages to \(targetFormat.displayName)")
                    }
                }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(convertButtonGradient)
                    )
            }
            .disabled(selectedCount == 0)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var convertButtonGradient: LinearGradient {
        if selectedCount == 0 {
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

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Text("PDF to Image")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.textSecondary.opacity(0.08)))
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }

        isLoadingPDF = true
        let name = sourceURL.lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_pdf_to_image", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destURL)

        DispatchQueue.global(qos: .userInitiated).async {
            var copiedURL: URL?
            if let _ = try? FileManager.default.copyItem(at: sourceURL, to: destURL) {
                copiedURL = destURL
            }
            sourceURL.stopAccessingSecurityScopedResource()

            guard let url = copiedURL, let doc = PDFDocument(url: url) else {
                DispatchQueue.main.async { isLoadingPDF = false }
                return
            }

            let count = doc.pageCount
            let thumbnailSize = CGSize(width: 200, height: 280)
            var thumbnails: [Int: UIImage] = [:]
            for i in 0..<count {
                guard let page = doc.page(at: i) else { continue }
                thumbnails[i] = page.thumbnail(of: thumbnailSize, for: .mediaBox)
            }

            DispatchQueue.main.async {
                fileURL = url
                fileName = name
                pageCount = count
                selectedPages = [:]
                pageThumbnails = thumbnails
                isLoadingPDF = false
            }
        }
    }

    private func performConvert() {
        guard let url = fileURL, selectedCount > 0 else { return }
        let sortedPages = selectedPages.filter { $0.value }.keys.sorted()
        onConvert(url, fileName, targetFormat, sortedPages)
    }
}
