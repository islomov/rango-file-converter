import Foundation
import PDFKit

enum PDFToolsError: LocalizedError {
    case fileNotFound
    case corruptPDF
    case invalidPageRange
    case noPages
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "PDF file not found."
        case .corruptPDF: return "The PDF file is corrupt or unreadable."
        case .invalidPageRange: return "Invalid page range specified."
        case .noPages: return "No pages to process."
        case .writeFailed: return "Failed to write the output PDF."
        }
    }
}

struct PDFToolsService {

    // MARK: - Merge

    /// Merges multiple PDF files into a single PDF.
    static func merge(pdfURLs: [URL]) throws -> URL {
        guard !pdfURLs.isEmpty else { throw PDFToolsError.noPages }

        let merged = PDFDocument()
        var pageIndex = 0

        for url in pdfURLs {
            guard let doc = PDFDocument(url: url) else { throw PDFToolsError.corruptPDF }
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                merged.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }

        guard merged.pageCount > 0 else { throw PDFToolsError.noPages }

        let outputURL = makeOutputURL(suffix: "merged")
        guard merged.write(to: outputURL) else { throw PDFToolsError.writeFailed }
        return outputURL
    }

    // MARK: - Split

    /// Extracts specified pages (0-indexed) from a PDF into a new PDF.
    static func split(pdfURL: URL, pages: [Int]) throws -> URL {
        guard let doc = PDFDocument(url: pdfURL) else { throw PDFToolsError.corruptPDF }
        guard !pages.isEmpty else { throw PDFToolsError.noPages }

        let result = PDFDocument()
        var insertIndex = 0

        for pageNum in pages {
            guard pageNum >= 0 && pageNum < doc.pageCount else { throw PDFToolsError.invalidPageRange }
            guard let page = doc.page(at: pageNum) else { continue }
            result.insert(page, at: insertIndex)
            insertIndex += 1
        }

        guard result.pageCount > 0 else { throw PDFToolsError.noPages }

        let outputURL = makeOutputURL(suffix: "split")
        guard result.write(to: outputURL) else { throw PDFToolsError.writeFailed }
        return outputURL
    }

    // MARK: - Reorder

    /// Reorders pages in a PDF according to the given page order (0-indexed).
    static func reorder(pdfURL: URL, pageOrder: [Int]) throws -> URL {
        guard let doc = PDFDocument(url: pdfURL) else { throw PDFToolsError.corruptPDF }
        guard !pageOrder.isEmpty else { throw PDFToolsError.noPages }

        let result = PDFDocument()

        for (insertIndex, pageNum) in pageOrder.enumerated() {
            guard pageNum >= 0 && pageNum < doc.pageCount else { throw PDFToolsError.invalidPageRange }
            guard let page = doc.page(at: pageNum) else { continue }
            result.insert(page, at: insertIndex)
        }

        guard result.pageCount > 0 else { throw PDFToolsError.noPages }

        let outputURL = makeOutputURL(suffix: "reordered")
        guard result.write(to: outputURL) else { throw PDFToolsError.writeFailed }
        return outputURL
    }

    // MARK: - Protect

    /// Adds password protection to a PDF using Core Graphics.
    static func protect(pdfURL: URL, password: String) throws -> URL {
        guard let doc = PDFDocument(url: pdfURL) else { throw PDFToolsError.corruptPDF }
        guard doc.pageCount > 0 else { throw PDFToolsError.noPages }

        let outputURL = makeOutputURL(suffix: "protected")

        // Use CGPDFDocument for encryption since PDFKit doesn't support writing encrypted PDFs directly
        guard let dataProvider = CGDataProvider(url: pdfURL as CFURL),
              let cgPDF = CGPDFDocument(dataProvider) else {
            throw PDFToolsError.corruptPDF
        }

        let encryptionOptions: [CFString: Any] = [
            kCGPDFContextUserPassword: password,
            kCGPDFContextOwnerPassword: password,
        ]

        // Get media box from first page for context creation
        guard let firstPage = cgPDF.page(at: 1) else { throw PDFToolsError.noPages }
        var mediaBox = firstPage.getBoxRect(.mediaBox)

        guard let context = CGContext(outputURL as CFURL, mediaBox: &mediaBox, encryptionOptions as CFDictionary) else {
            throw PDFToolsError.writeFailed
        }

        for pageNum in 1...cgPDF.numberOfPages {
            guard let page = cgPDF.page(at: pageNum) else { continue }
            var pageBox = page.getBoxRect(.mediaBox)
            context.beginPage(mediaBox: &pageBox)

            context.translateBy(x: 0, y: pageBox.height)
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: pageBox.height)
            context.scaleBy(x: 1, y: -1)

            context.drawPDFPage(page)
            context.endPage()
        }

        context.closePDF()
        return outputURL
    }

    // MARK: - Helpers

    private static func makeOutputURL(suffix: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let shortID = UUID().uuidString.prefix(8)
        return tempDir.appendingPathComponent("\(suffix)_\(shortID).pdf")
    }
}
