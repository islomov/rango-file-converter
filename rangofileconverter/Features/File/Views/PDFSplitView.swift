import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFSplitView: View {
    let onSplit: (URL, String, [Int]) -> Void

    @State private var fileURL: URL?
    @State private var fileName: String = ""
    @State private var pageCount: Int = 0
    @State private var pageRangeText: String = ""
    @State private var showFilePicker = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if fileURL == nil {
                    Spacer(minLength: 80)
                    VStack(spacing: 12) {
                        Image(systemName: "scissors")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Select a PDF to split")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Choose PDF", systemImage: "folder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 40)
                } else {
                    // File info
                    HStack {
                        Image(systemName: "doc.richtext")
                            .font(.title2)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fileName)
                                .font(.headline)
                            Text("\(pageCount) pages")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showFilePicker = true
                        } label: {
                            Text("Change")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    // Page range input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pages to extract")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("e.g., 1-3, 5, 7-10", text: $pageRangeText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                        Text("Enter page numbers and ranges separated by commas")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Split button
                    Button {
                        performSplit()
                    } label: {
                        Text("Split PDF")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pageRangeText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
        }
        .navigationTitle("Split PDF")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let name = sourceURL.lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_pdf_split", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destURL)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            fileURL = destURL
            fileName = name
            if let doc = PDFDocument(url: destURL) {
                pageCount = doc.pageCount
            }
            errorMessage = nil
            pageRangeText = ""
        } catch {
            // Copy failed
        }
    }

    private func performSplit() {
        errorMessage = nil
        guard let url = fileURL else { return }

        guard let pages = parsePageRanges(pageRangeText, maxPage: pageCount) else {
            errorMessage = "Invalid page range. Use format: 1-3, 5, 7-10"
            return
        }

        // Convert to 0-indexed
        let zeroIndexedPages = pages.map { $0 - 1 }
        onSplit(url, fileName, zeroIndexedPages)
    }

    /// Parses page range text like "1-3, 5, 7-10" into an array of 1-indexed page numbers.
    private func parsePageRanges(_ text: String, maxPage: Int) -> [Int]? {
        let parts = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var pages: [Int] = []

        for part in parts {
            if part.contains("-") {
                let range = part.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard range.count == 2, let start = Int(range[0]), let end = Int(range[1]),
                      start >= 1, end <= maxPage, start <= end else { return nil }
                pages.append(contentsOf: start...end)
            } else {
                guard let num = Int(part), num >= 1, num <= maxPage else { return nil }
                pages.append(num)
            }
        }

        return pages.isEmpty ? nil : pages
    }
}
