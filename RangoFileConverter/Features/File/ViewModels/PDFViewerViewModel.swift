import Foundation
import PDFKit
import Combine
import UIKit

final class PDFViewerViewModel: ObservableObject {

    // MARK: - File State

    @Published var fileURL: URL?
    @Published var fileName: String = ""
    @Published var pageCount: Int = 0
    @Published var currentPage: Int = 1

    // MARK: - Search

    @Published var isSearching = false
    @Published var searchText = ""
    @Published var searchResultCount = 0
    @Published var currentSearchIndex = 0

    // MARK: - Display

    @Published var displayMode: DisplayMode = .continuous
    @Published var readingMode: ReadingMode = .normal
    @Published var isHorizontal = false

    // MARK: - Annotation

    @Published var annotationMode: AnnotationMode = .none
    @Published var showAnnotationTools = false

    // MARK: - Text Note

    @Published var showNoteAlert = false
    @Published var noteText = ""
    var pendingNotePoint: CGPoint?

    // MARK: - Bookmarks

    @Published var bookmarks: Set<Int> = []
    @Published var showBookmarks = false

    // MARK: - Sheets / Overlays

    @Published var showThumbnails = false
    @Published var showDisplayOptions = false
    @Published var showGoToPage = false
    @Published var goToPageText = ""
    @Published var showFilePicker = false
    @Published var showShareDialog = false

    // MARK: - Share

    @Published var shareItems: [Any]?
    @Published var showActivitySheet = false

    // MARK: - Outline

    @Published var outlineItems: [OutlineItem] = []
    @Published var hasOutline = false

    // MARK: - Thumbnails

    @Published var thumbnails: [Int: UIImage] = [:]

    // MARK: - PDF View Reference

    weak var pdfView: PDFView?
    private var searchResults: [PDFSelection] = []

    // MARK: - Enums

    enum DisplayMode: String, CaseIterable {
        case singlePage = "Single Page"
        case continuous = "Continuous"
    }

    enum ReadingMode: String, CaseIterable {
        case normal = "Normal"
        case dark = "Dark"
        case sepia = "Sepia"
    }

    enum AnnotationMode: String, CaseIterable {
        case none = "None"
        case highlight = "Highlight"
        case underline = "Underline"
        case strikethrough = "Strikethrough"
        case freehand = "Draw"
        case textNote = "Note"
    }

    struct OutlineItem: Identifiable {
        let id = UUID()
        let title: String
        let pageIndex: Int
        let level: Int
    }

    enum BrowseTab: String, CaseIterable {
        case pages = "Pages"
        case outline = "Outline"
        case bookmarks = "Bookmarks"
    }

    // MARK: - Persistence Keys

    private var bookmarksKey: String { "pdfviewer_bm_\(fileName.hashValue)" }
    private var lastPageKey: String { "pdfviewer_lp_\(fileName.hashValue)" }

    // MARK: - Setup

    func setupDocument(url: URL, name: String) {
        // Reset state
        thumbnails = [:]
        bookmarks = []
        outlineItems = []
        hasOutline = false
        searchText = ""
        searchResults = []
        searchResultCount = 0
        currentSearchIndex = 0
        annotationMode = .none
        showAnnotationTools = false
        isSearching = false

        fileURL = url
        fileName = name

        guard let document = PDFDocument(url: url) else { return }
        pageCount = document.pageCount

        loadBookmarks()
        loadOutline(from: document)

        if let lastPage = loadLastPage(), lastPage > 0, lastPage <= pageCount {
            currentPage = lastPage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.goToPage(lastPage)
            }
        } else {
            currentPage = 1
        }

        generateThumbnails(document: document)
    }

    // MARK: - Navigation

    func goToPage(_ page: Int) {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              page > 0, page <= pageCount,
              let pdfPage = document.page(at: page - 1) else { return }
        pdfView.go(to: pdfPage)
        currentPage = page
        saveLastPage()
    }

    func nextPage() {
        if currentPage < pageCount { goToPage(currentPage + 1) }
    }

    func previousPage() {
        if currentPage > 1 { goToPage(currentPage - 1) }
    }

    func updateCurrentPage(_ page: Int) {
        guard page != currentPage else { return }
        currentPage = page
        saveLastPage()
    }

    // MARK: - Search

    func performSearch() {
        guard let document = pdfView?.document, !searchText.isEmpty else {
            clearSearch()
            return
        }
        searchResults = document.findString(searchText, withOptions: [.caseInsensitive])
        searchResultCount = searchResults.count
        currentSearchIndex = 0
        highlightCurrentResult()
    }

    func nextSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        highlightCurrentResult()
    }

    func previousSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        highlightCurrentResult()
    }

    func clearSearch() {
        searchResults = []
        searchResultCount = 0
        currentSearchIndex = 0
        pdfView?.clearSelection()
    }

    private func highlightCurrentResult() {
        guard !searchResults.isEmpty else { return }
        let selection = searchResults[currentSearchIndex]
        pdfView?.setCurrentSelection(selection, animate: true)
        if let page = selection.pages.first {
            pdfView?.go(to: page)
        }
    }

    // MARK: - Display

    func applyDisplayMode() {
        guard let pdfView = pdfView else { return }
        switch displayMode {
        case .singlePage:
            pdfView.displayMode = .singlePage
        case .continuous:
            pdfView.displayMode = .singlePageContinuous
        }
        pdfView.displayDirection = isHorizontal ? .horizontal : .vertical
    }

    func toggleFitMode() {
        guard let pdfView = pdfView else { return }
        if pdfView.autoScales {
            pdfView.autoScales = false
            if let page = pdfView.currentPage {
                let pageRect = page.bounds(for: .mediaBox)
                let viewWidth = pdfView.bounds.width - 20
                pdfView.scaleFactor = viewWidth / pageRect.width
            }
        } else {
            pdfView.autoScales = true
        }
    }

    func rotatePages() {
        guard let document = pdfView?.document else { return }
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                page.rotation = (page.rotation + 90) % 360
            }
        }
        pdfView?.layoutDocumentView()
    }

    // MARK: - Annotations (text-based)

    func applyAnnotationToSelection() {
        guard let pdfView = pdfView,
              let selection = pdfView.currentSelection,
              annotationMode == .highlight || annotationMode == .underline || annotationMode == .strikethrough
        else { return }

        let lineSelections = selection.selectionsByLine() ?? [selection]
        let color: UIColor
        let type: PDFAnnotationSubtype

        switch annotationMode {
        case .highlight:
            type = .highlight
            color = UIColor.yellow.withAlphaComponent(0.5)
        case .underline:
            type = .underline
            color = .red
        case .strikethrough:
            type = .strikeOut
            color = .red
        default:
            return
        }

        for lineSelection in lineSelections {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }
                let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
                annotation.color = color
                page.addAnnotation(annotation)
            }
        }
        pdfView.clearSelection()
    }

    // MARK: - Annotations (freehand)

    func addFreehandAnnotation(viewPoints: [CGPoint]) {
        guard let pdfView = pdfView,
              let currentPDFPage = pdfView.currentPage,
              viewPoints.count > 1 else { return }

        let pdfPoints = viewPoints.map { pdfView.convert($0, to: currentPDFPage) }

        let xs = pdfPoints.map { $0.x }
        let ys = pdfPoints.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return }

        let padding: CGFloat = 5
        let bounds = CGRect(
            x: minX - padding, y: minY - padding,
            width: maxX - minX + padding * 2, height: maxY - minY + padding * 2
        )

        let path = UIBezierPath()
        path.move(to: pdfPoints[0])
        for point in pdfPoints.dropFirst() {
            path.addLine(to: point)
        }

        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.add(path)
        annotation.color = .red
        let border = PDFBorder()
        border.lineWidth = 2.0
        annotation.border = border
        currentPDFPage.addAnnotation(annotation)
    }

    // MARK: - Annotations (text note)

    func addTextNote(at viewPoint: CGPoint, text: String) {
        guard let pdfView = pdfView,
              let page = pdfView.page(for: viewPoint, nearest: true) else { return }
        let pagePoint = pdfView.convert(viewPoint, to: page)
        let bounds = CGRect(x: pagePoint.x - 12, y: pagePoint.y - 12, width: 24, height: 24)
        let annotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        annotation.color = .yellow
        annotation.contents = text
        page.addAnnotation(annotation)
    }

    func confirmTextNote() {
        guard let point = pendingNotePoint, !noteText.isEmpty else {
            pendingNotePoint = nil
            noteText = ""
            return
        }
        addTextNote(at: point, text: noteText)
        pendingNotePoint = nil
        noteText = ""
    }

    // MARK: - Bookmarks

    func toggleBookmark() {
        if bookmarks.contains(currentPage) {
            bookmarks.remove(currentPage)
        } else {
            bookmarks.insert(currentPage)
        }
        saveBookmarks()
    }

    var isCurrentPageBookmarked: Bool {
        bookmarks.contains(currentPage)
    }

    private func loadBookmarks() {
        let array = UserDefaults.standard.array(forKey: bookmarksKey) as? [Int] ?? []
        bookmarks = Set(array)
    }

    private func saveBookmarks() {
        UserDefaults.standard.set(Array(bookmarks).sorted(), forKey: bookmarksKey)
    }

    // MARK: - Last Page Persistence

    private func loadLastPage() -> Int? {
        let page = UserDefaults.standard.integer(forKey: lastPageKey)
        return page > 0 ? page : nil
    }

    private func saveLastPage() {
        UserDefaults.standard.set(currentPage, forKey: lastPageKey)
    }

    // MARK: - Outline

    private func loadOutline(from document: PDFDocument) {
        guard let root = document.outlineRoot else {
            hasOutline = false
            return
        }
        var items: [OutlineItem] = []
        flattenOutline(root, level: 0, into: &items, document: document)
        outlineItems = items
        hasOutline = !items.isEmpty
    }

    private func flattenOutline(_ outline: PDFOutline, level: Int, into items: inout [OutlineItem], document: PDFDocument) {
        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }
            let title = child.label ?? "Untitled"
            var pageIndex = 0
            if let destination = child.destination, let page = destination.page {
                pageIndex = document.index(for: page)
            }
            items.append(OutlineItem(title: title, pageIndex: pageIndex, level: level))
            flattenOutline(child, level: level + 1, into: &items, document: document)
        }
    }

    // MARK: - Thumbnails

    private func generateThumbnails(document: PDFDocument) {
        let count = document.pageCount
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var thumbs: [Int: UIImage] = [:]
            let size = CGSize(width: 120, height: 160)
            for i in 0..<count {
                guard let page = document.page(at: i) else { continue }
                thumbs[i] = page.thumbnail(of: size, for: .mediaBox)
            }
            DispatchQueue.main.async {
                self?.thumbnails = thumbs
            }
        }
    }

    // MARK: - Share

    func renderCurrentPageAsImage() -> UIImage? {
        guard let page = pdfView?.currentPage else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    func sharePageAsImage() {
        guard let image = renderCurrentPageAsImage() else { return }
        shareItems = [image]
        showActivitySheet = true
    }

    func sharePDF() {
        guard let url = fileURL else { return }
        shareItems = [url]
        showActivitySheet = true
    }

    func printPDF() {
        guard let url = fileURL else { return }
        let printController = UIPrintInteractionController.shared
        printController.printingItem = url
        printController.present(animated: true)
    }
}
