import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFReorderView: View {
    let onReorder: (URL, String, [Int]) -> Void

    @State private var fileURL: URL?
    @State private var fileName: String = ""
    @State private var pageItems: [PageItem] = []
    @State private var showFilePicker = false

    struct PageItem: Identifiable {
        let id = UUID()
        let originalIndex: Int // 0-indexed
        let thumbnail: UIImage?
    }

    var body: some View {
        VStack(spacing: 0) {
            if fileURL == nil {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select a PDF to reorder pages")
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
                .padding(.top, 24)
                Spacer()
            } else {
                // File info header
                HStack {
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(.red)
                    Text(fileName)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(pageItems.count) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showFilePicker = true
                    } label: {
                        Text("Change")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Text("Drag to reorder pages")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)

                // Page list
                List {
                    ForEach(pageItems) { item in
                        HStack(spacing: 12) {
                            if let thumb = item.thumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 70)
                                    .border(Color.secondary.opacity(0.3))
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.quaternary)
                                    .frame(width: 50, height: 70)
                            }
                            Text("Page \(item.originalIndex + 1)")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    .onMove { from, to in
                        pageItems.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))

                // Reorder button
                Button {
                    let order = pageItems.map { $0.originalIndex }
                    onReorder(fileURL!, fileName, order)
                } label: {
                    Text("Apply New Order")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(16)
            }
        }
        .navigationTitle("Reorder Pages")
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
            .appendingPathComponent("rango_pdf_reorder", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destURL)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            fileURL = destURL
            fileName = name
            loadPages(from: destURL)
        } catch {
            // Copy failed
        }
    }

    private func loadPages(from url: URL) {
        guard let doc = PDFDocument(url: url) else { return }
        let thumbSize = CGSize(width: 100, height: 140)
        var items: [PageItem] = []

        for i in 0..<doc.pageCount {
            let thumb = doc.page(at: i)?.thumbnail(of: thumbSize, for: .mediaBox)
            items.append(PageItem(originalIndex: i, thumbnail: thumb))
        }

        pageItems = items
    }
}
