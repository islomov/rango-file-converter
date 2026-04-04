import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Main View

struct PDFViewerView: View {
    @StateObject private var viewModel = PDFViewerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            if viewModel.fileURL == nil {
                emptyState
            } else {
                viewerState
            }
        }
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .typedFilePicker(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        // Go to Page alert
        .alert("Go to Page", isPresented: $viewModel.showGoToPage) {
            TextField("Page number", text: $viewModel.goToPageText)
                .keyboardType(.numberPad)
            Button("Go") {
                if let page = Int(viewModel.goToPageText) {
                    viewModel.goToPage(page)
                }
                viewModel.goToPageText = ""
            }
            Button("Cancel", role: .cancel) { viewModel.goToPageText = "" }
        } message: {
            Text("Enter page number (1–\(viewModel.pageCount))")
        }
        // Text Note alert
        .alert("Add Note", isPresented: $viewModel.showNoteAlert) {
            TextField("Note text", text: $viewModel.noteText)
            Button("Add") { viewModel.confirmTextNote() }
            Button("Cancel", role: .cancel) {
                viewModel.noteText = ""
                viewModel.pendingNotePoint = nil
            }
        }
        // Share dialog
        .confirmationDialog("Share", isPresented: $viewModel.showShareDialog, titleVisibility: .visible) {
            Button("Share PDF") { viewModel.sharePDF() }
            Button("Share Page as Image") { viewModel.sharePageAsImage() }
            Button("Print") { viewModel.printPDF() }
        }
        // Activity sheet
        .sheet(isPresented: $viewModel.showActivitySheet) {
            if let items = viewModel.shareItems {
                ActivityRepresentable(activityItems: items)
            }
        }
        // Thumbnail / Outline / Bookmarks sheet
        .sheet(isPresented: $viewModel.showThumbnails) {
            browseSheet
        }
        // Display options sheet
        .sheet(isPresented: $viewModel.showDisplayOptions) {
            displayOptionsSheet
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            navBar

            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.accent)

                    Text("Select a PDF to view")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .multilineTextAlignment(.center)
                }

                Button {
                    viewModel.showFilePicker = true
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

    // MARK: - Viewer State

    private var viewerState: some View {
        VStack(spacing: 0) {
            navBar
                .background(AppColors.surface)

            fileInfoRow

            // Search overlay
            if viewModel.isSearching {
                searchBar
            }

            // Annotation toolbar
            if viewModel.showAnnotationTools {
                annotationToolbar
            }

            // PDF content with reading mode
            ZStack {
                pdfContentView

                // Sepia overlay
                if viewModel.readingMode == .sepia {
                    Color(red: 0.94, green: 0.87, blue: 0.74)
                        .opacity(0.2)
                        .allowsHitTesting(false)
                }
            }

            pageNavigator

            bottomToolbar
        }
    }

    @ViewBuilder
    private var pdfContentView: some View {
        let baseView = PDFKitRepresentable(
            url: viewModel.fileURL!,
            viewModel: viewModel
        )
        if viewModel.readingMode == .dark {
            baseView
                .colorInvert()
                .background(Color.black)
        } else {
            baseView
        }
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Text("View PDF")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Spacer()

                // Bookmark toggle
                Button {
                    viewModel.toggleBookmark()
                } label: {
                    Image(systemName: viewModel.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(viewModel.isCurrentPageBookmarked ? AppColors.accent : AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                }

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

    // MARK: - File Info Row

    private var fileInfoRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.placeholder)
                    .frame(width: 28, height: 28)

                Image(systemName: "doc.text.magnifyingglass")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.fileName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-0.408)
                    .lineLimit(1)

                Text("\(viewModel.pageCount) pages")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)
            }

            Spacer()

            Button {
                viewModel.showFilePicker = true
            } label: {
                Text("Change")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(-0.408)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)

                TextField("Search in PDF", text: $viewModel.searchText)
                    .font(.system(size: 14))
                    .submitLabel(.search)
                    .onSubmit { viewModel.performSearch() }

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColors.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            if viewModel.searchResultCount > 0 {
                HStack(spacing: 4) {
                    Text("\(viewModel.currentSearchIndex + 1)/\(viewModel.searchResultCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .monospacedDigit()

                    Button { viewModel.previousSearchResult() } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 28, height: 28)
                    }
                    Button { viewModel.nextSearchResult() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 28, height: 28)
                    }
                }
            }

            Button {
                viewModel.isSearching = false
                viewModel.clearSearch()
                viewModel.searchText = ""
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Annotation Toolbar

    private var annotationToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PDFViewerViewModel.AnnotationMode.allCases, id: \.rawValue) { mode in
                    if mode != .none {
                        Button {
                            if viewModel.annotationMode == mode {
                                viewModel.annotationMode = .none
                            } else {
                                viewModel.annotationMode = mode
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: annotationIcon(for: mode))
                                    .font(.system(size: 12))
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(viewModel.annotationMode == mode ? .white : AppColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.annotationMode == mode
                                    ? AnyShapeStyle(AppColors.accent)
                                    : AnyShapeStyle(AppColors.textSecondary.opacity(0.08))
                            )
                            .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Button {
                    viewModel.annotationMode = .none
                    viewModel.showAnnotationTools = false
                } label: {
                    Text("Done")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func annotationIcon(for mode: PDFViewerViewModel.AnnotationMode) -> String {
        switch mode {
        case .none: return ""
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .freehand: return "pencil.tip"
        case .textNote: return "note.text"
        }
    }

    // MARK: - Page Navigator

    private var pageNavigator: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)

            HStack {
                Button { viewModel.previousPage() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.currentPage > 1 ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.3))
                        .frame(width: 36, height: 36)
                }
                .disabled(viewModel.currentPage <= 1)

                Spacer()

                Button {
                    viewModel.showGoToPage = true
                } label: {
                    Text("Page \(viewModel.currentPage) of \(viewModel.pageCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }

                Spacer()

                Button { viewModel.nextPage() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.currentPage < viewModel.pageCount ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.3))
                        .frame(width: 36, height: 36)
                }
                .disabled(viewModel.currentPage >= viewModel.pageCount)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(AppColors.surface)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "magnifyingglass", label: "Search") {
                viewModel.isSearching.toggle()
                if !viewModel.isSearching {
                    viewModel.clearSearch()
                    viewModel.searchText = ""
                }
            }

            toolbarButton(icon: "square.grid.2x2", label: "Browse") {
                viewModel.showThumbnails = true
            }

            toolbarButton(icon: "pencil.tip.crop.circle", label: "Annotate") {
                viewModel.showAnnotationTools.toggle()
                if !viewModel.showAnnotationTools {
                    viewModel.annotationMode = .none
                }
            }

            toolbarButton(icon: "square.and.arrow.up", label: "Share") {
                viewModel.showShareDialog = true
            }

            toolbarButton(icon: "gearshape", label: "Display") {
                viewModel.showDisplayOptions = true
            }
        }
        .padding(.bottom, 8)
        .background(AppColors.surface)
    }

    private func toolbarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
    }

    // MARK: - Browse Sheet (Thumbnails / Outline / Bookmarks)

    private var browseSheet: some View {
        NavigationView {
            BrowseSheetContent(viewModel: viewModel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            viewModel.showThumbnails = false
                        }
                    }
                }
        }
        .presentationDetents([.large])
    }

    // MARK: - Display Options Sheet

    private var displayOptionsSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Reading Mode
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reading Mode")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: 8) {
                            ForEach(PDFViewerViewModel.ReadingMode.allCases, id: \.rawValue) { mode in
                                Button {
                                    viewModel.readingMode = mode
                                } label: {
                                    Text(mode.rawValue)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(viewModel.readingMode == mode ? .white : AppColors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            viewModel.readingMode == mode
                                                ? AnyShapeStyle(AppColors.accent)
                                                : AnyShapeStyle(AppColors.textSecondary.opacity(0.08))
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Layout
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Layout")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: 8) {
                            ForEach(PDFViewerViewModel.DisplayMode.allCases, id: \.rawValue) { mode in
                                Button {
                                    viewModel.displayMode = mode
                                    viewModel.applyDisplayMode()
                                } label: {
                                    Text(mode.rawValue)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(viewModel.displayMode == mode ? .white : AppColors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            viewModel.displayMode == mode
                                                ? AnyShapeStyle(AppColors.accent)
                                                : AnyShapeStyle(AppColors.textSecondary.opacity(0.08))
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Scroll Direction
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scroll Direction")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: 8) {
                            Button {
                                viewModel.isHorizontal = false
                                viewModel.applyDisplayMode()
                            } label: {
                                Label("Vertical", systemImage: "arrow.up.arrow.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(!viewModel.isHorizontal ? .white : AppColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        !viewModel.isHorizontal
                                            ? AnyShapeStyle(AppColors.accent)
                                            : AnyShapeStyle(AppColors.textSecondary.opacity(0.08))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Button {
                                viewModel.isHorizontal = true
                                viewModel.applyDisplayMode()
                            } label: {
                                Label("Horizontal", systemImage: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(viewModel.isHorizontal ? .white : AppColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        viewModel.isHorizontal
                                            ? AnyShapeStyle(AppColors.accent)
                                            : AnyShapeStyle(AppColors.textSecondary.opacity(0.08))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            viewModel.toggleFitMode()
                        } label: {
                            displayActionRow(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", title: "Toggle Fit Width / Fit Page")
                        }

                        Button {
                            viewModel.rotatePages()
                        } label: {
                            displayActionRow(icon: "rotate.right", title: "Rotate 90°")
                        }

                        Button {
                            viewModel.showDisplayOptions = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.showGoToPage = true
                            }
                        } label: {
                            displayActionRow(icon: "number", title: "Go to Page…")
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.background)
            .navigationTitle("Display Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { viewModel.showDisplayOptions = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func displayActionRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(AppColors.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let name = sourceURL.lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_pdf_viewer", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destURL)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            viewModel.setupDocument(url: destURL, name: name)
        } catch {
            // File copy failed
        }
    }
}

// MARK: - Browse Sheet Content

private struct BrowseSheetContent: View {
    @ObservedObject var viewModel: PDFViewerViewModel
    @State private var selectedTab: PDFViewerViewModel.BrowseTab = .pages
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(PDFViewerViewModel.BrowseTab.allCases, id: \.rawValue) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            switch selectedTab {
            case .pages:
                thumbnailGrid
            case .outline:
                outlineList
            case .bookmarks:
                bookmarksList
            }
        }
        .background(AppColors.background)
    }

    // MARK: - Thumbnail Grid

    private var thumbnailGrid: some View {
        ScrollView {
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ]

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<viewModel.pageCount, id: \.self) { index in
                    Button {
                        viewModel.goToPage(index + 1)
                        dismiss()
                    } label: {
                        VStack(spacing: 4) {
                            if let thumb = viewModel.thumbnails[index] {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 140)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                viewModel.currentPage == index + 1 ? AppColors.accent : AppColors.border,
                                                lineWidth: viewModel.currentPage == index + 1 ? 2.5 : 1
                                            )
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppColors.placeholder)
                                    .frame(height: 140)
                            }

                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(
                                    viewModel.currentPage == index + 1
                                        ? AppColors.accent
                                        : AppColors.textSecondary
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Outline List

    private var outlineList: some View {
        Group {
            if viewModel.outlineItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "list.bullet")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No table of contents")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.outlineItems) { item in
                        Button {
                            viewModel.goToPage(item.pageIndex + 1)
                            dismiss()
                        } label: {
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 14, weight: item.level == 0 ? .semibold : .regular))
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding(.leading, CGFloat(item.level) * 16)
                                Spacer()
                                Text("\(item.pageIndex + 1)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Bookmarks List

    private var bookmarksList: some View {
        Group {
            if viewModel.bookmarks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No bookmarks yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap the bookmark icon to save pages")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.bookmarks.sorted(), id: \.self) { page in
                        Button {
                            viewModel.goToPage(page)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                if let thumb = viewModel.thumbnails[page - 1] {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 40, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(AppColors.border, lineWidth: 1)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Page \(page)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                }

                                Spacer()

                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - PDFKit UIViewRepresentable

struct PDFKitRepresentable: UIViewRepresentable {
    let url: URL
    let viewModel: PDFViewerViewModel

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        // PDF View
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(AppColors.background)
        pdfView.document = PDFDocument(url: url)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pdfView)

        // Drawing overlay
        let overlay = DrawingOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        overlay.pdfView = pdfView
        overlay.viewModel = viewModel
        container.addSubview(overlay)

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: container.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        viewModel.pdfView = pdfView
        context.coordinator.pdfView = pdfView
        context.coordinator.overlay = overlay
        context.coordinator.viewModel = viewModel

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        let isDrawing = viewModel.annotationMode == .freehand
        let isNoting = viewModel.annotationMode == .textNote
        context.coordinator.overlay?.isUserInteractionEnabled = isDrawing || isNoting

        // Update document if URL changed
        if let pdfView = context.coordinator.pdfView,
           pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        weak var pdfView: PDFView?
        weak var overlay: DrawingOverlayView?
        weak var viewModel: PDFViewerViewModel?
        private var annotationTimer: Timer?

        @objc func pageChanged() {
            guard let pdfView = pdfView,
                  let current = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let index = document.index(for: current)
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.updateCurrentPage(index + 1)
            }
        }

        @objc func selectionChanged() {
            annotationTimer?.invalidate()
            guard let vm = viewModel,
                  vm.annotationMode == .highlight || vm.annotationMode == .underline || vm.annotationMode == .strikethrough
            else { return }

            annotationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.viewModel?.applyAnnotationToSelection()
                }
            }
        }
    }
}

// MARK: - Drawing Overlay

class DrawingOverlayView: UIView {
    weak var pdfView: PDFView?
    weak var viewModel: PDFViewerViewModel?
    private var currentPoints: [CGPoint] = []
    private var currentPath: UIBezierPath?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if viewModel?.annotationMode == .freehand {
            currentPoints = [point]
            currentPath = UIBezierPath()
            currentPath?.move(to: point)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard viewModel?.annotationMode == .freehand,
              let touch = touches.first else { return }
        let point = touch.location(in: self)
        currentPoints.append(point)
        currentPath?.addLine(to: point)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let pdfView = pdfView else { return }

        if viewModel?.annotationMode == .freehand, currentPoints.count > 1 {
            // Convert overlay points to PDFView coordinates
            let pdfViewPoints = currentPoints.map { self.convert($0, to: pdfView) }
            viewModel?.addFreehandAnnotation(viewPoints: pdfViewPoints)
        } else if viewModel?.annotationMode == .textNote {
            // Single tap for text note
            let point = touch.location(in: self)
            let pdfViewPoint = self.convert(point, to: pdfView)
            viewModel?.pendingNotePoint = pdfViewPoint
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.showNoteAlert = true
            }
        }

        currentPath = nil
        currentPoints = []
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let path = currentPath else { return }
        UIColor.red.setStroke()
        path.lineWidth = 3
        path.stroke()
    }
}

// MARK: - Activity View Controller

struct ActivityRepresentable: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
