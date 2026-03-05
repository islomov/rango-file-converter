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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "F2F2F6")
                .ignoresSafeArea()

            if fileURL == nil {
                emptyState
            } else {
                detailState
            }
        }
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .fileImporter(
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
                    Image("icon_doc_split")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 56, height: 56)

                    Text("Select a PDF to split")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
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
                                colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
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

            ScrollView {
                VStack(spacing: 24) {
                    // File info
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8.32)
                                .fill(Color(hex: "E6E6EC"))
                                .frame(width: 56, height: 56)

                            Image("icon_doc_split")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color(hex: "888888"))
                                .frame(width: 24, height: 24)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(fileName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "1D1D1D"))
                                .tracking(-0.408)
                                .lineLimit(1)

                            Text("\(pageCount) pages")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "888888"))
                                .tracking(-0.408)
                        }

                        Spacer()

                        Button {
                            showFilePicker = true
                        } label: {
                            Text("Change")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "F4800D"))
                                .tracking(-0.408)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    )

                    // Page range input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pages to extract")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                            .tracking(-0.408)

                        TextField("e.g., 1-3, 5, 7-10", text: $pageRangeText)
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.408)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                            )
                            .keyboardType(.numbersAndPunctuation)

                        Text("Enter page numbers and ranges separated by commas")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                            .tracking(-0.408)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "F21414"))
                            .tracking(-0.408)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            // Split button
            Button {
                performSplit()
            } label: {
                Text("Split PDF")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(splitButtonGradient)
                    )
            }
            .disabled(pageRangeText.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Text("Split PDF")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image("icon_arrow_left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    private var splitButtonGradient: LinearGradient {
        let isEmpty = pageRangeText.trimmingCharacters(in: .whitespaces).isEmpty
        if isEmpty {
            return LinearGradient(
                colors: [Color(hex: "FFD9B8"), Color(hex: "F8C192"), Color(hex: "FFD9B8")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    // MARK: - File Import

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

        let zeroIndexedPages = pages.map { $0 - 1 }
        onSplit(url, fileName, zeroIndexedPages)
    }

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
