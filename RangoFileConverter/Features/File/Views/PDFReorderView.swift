import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFReorderView: View {
    let onReorder: (URL, String, [Int]) -> Void

    @State private var fileURL: URL?
    @State private var fileName: String = ""
    @State private var pageItems: [PageItem] = []
    @State private var showFilePicker = false
    @State private var draggingItem: PageItem?
    @State private var hasReordered: Bool = false
    @State private var isLoadingPDF = false
    @Environment(\.dismiss) private var dismiss

    struct PageItem: Identifiable, Equatable {
        let id = UUID()
        let originalIndex: Int
        let thumbnail: UIImage?

        static func == (lhs: PageItem, rhs: PageItem) -> Bool {
            lhs.id == rhs.id
        }
    }


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
                    Image("icon_doc_reorder")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 56, height: 56)

                    Text("Select a PDF to reorder pages")
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
            detailNavBar

            // File info
            HStack(spacing: 10) {
                Image("icon_doc_reorder")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 20, height: 20)

                Text(fileName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-0.408)
                    .lineLimit(1)

                Text("\(pageItems.count) pages")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                Spacer()

                Button {
                    showFilePicker = true
                } label: {
                    Text("Change")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .tracking(-0.408)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.top, 8)

            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)

            // Drag & drop hint
            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)

                Text("Hold and drag pages to reorder them")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppColors.textSecondary.opacity(0.06))

            // Page grid
            ScrollView {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ]

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(pageItems) { item in
                        pageCell(item)
                            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 8))
                            .onDrag {
                                draggingItem = item
                                return NSItemProvider(object: item.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: PageDropDelegate(
                                item: item,
                                pageItems: $pageItems,
                                draggingItem: $draggingItem,
                                hasReordered: $hasReordered
                            ))
                    }
                }
                .padding(16)
            }

            bottomSection
        }
        .background(AppColors.surface)
    }

    // MARK: - Page Cell

    private func pageCell(_ item: PageItem) -> some View {
        let currentIndex = pageItems.firstIndex(of: item).map { $0 + 1 } ?? 0
        let isDragging = draggingItem?.id == item.id

        return VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                // Thumbnail
                if let thumb = item.thumbnail {
                    Image(uiImage: thumb)
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

                // Page number badge
                Text("\(currentIndex)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle().fill(AppColors.accent)
                    )
                    .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.textSecondary.opacity(0.12), lineWidth: 1)
            )

            // Label
            Text("Page \(item.originalIndex + 1)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(-0.408)
        }
        .contentShape(Rectangle())
        .opacity(isDragging ? 0.4 : 1.0)
    }

    // MARK: - Navigation Bars

    private var navBar: some View {
        ZStack {
            Text("Reorder pages")
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
                        .background(Circle().fill(AppColors.textSecondary.opacity(0.08)))
                }
                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    private var detailNavBar: some View {
        ZStack {
            Text("Reorder pages")
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

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)

            Button {
                guard let url = fileURL else { return }
                let order = pageItems.map { $0.originalIndex }
                onReorder(url, fileName, order)
            } label: {
                Text("Apply New Order")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }

        isLoadingPDF = true
        let name = sourceURL.lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_pdf_reorder", isDirectory: true)
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

            let thumbSize = CGSize(width: 200, height: 280)
            var items: [PageItem] = []
            for i in 0..<doc.pageCount {
                let thumb = doc.page(at: i)?.thumbnail(of: thumbSize, for: .mediaBox)
                items.append(PageItem(originalIndex: i, thumbnail: thumb))
            }

            DispatchQueue.main.async {
                fileURL = url
                fileName = name
                pageItems = items
                isLoadingPDF = false
            }
        }
    }
}

// MARK: - Drop Delegate

private struct PageDropDelegate: DropDelegate {
    let item: PDFReorderView.PageItem
    @Binding var pageItems: [PDFReorderView.PageItem]
    @Binding var draggingItem: PDFReorderView.PageItem?
    @Binding var hasReordered: Bool

    func performDrop(info: DropInfo) -> Bool {
        withAnimation {
            draggingItem = nil
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != item.id,
              let fromIndex = pageItems.firstIndex(of: dragging),
              let toIndex = pageItems.firstIndex(of: item)
        else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            pageItems.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
        hasReordered = true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // No-op — keep draggingItem so other cells can still receive it
    }

    func validateDrop(info: DropInfo) -> Bool {
        true
    }
}
