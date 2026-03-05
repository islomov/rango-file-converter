import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFReorderView: View {
    let onReorder: (URL, String, [Int]) -> Void

    @State private var fileURL: URL?
    @State private var fileName: String = ""
    @State private var pageItems: [PageItem] = []
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    struct PageItem: Identifiable {
        let id = UUID()
        let originalIndex: Int // 0-indexed
        let thumbnail: UIImage?
    }

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
                    Image("icon_doc_reorder")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 56, height: 56)

                    Text("Select a PDF to reorder pages")
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

            // File info header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8.32)
                        .fill(Color(hex: "E6E6EC"))
                        .frame(width: 56, height: 56)

                    Image("icon_doc_reorder")
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

                    Text("\(pageItems.count) pages")
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
            .background(Color.white)

            Text("Drag to reorder pages")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "888888"))
                .tracking(-0.408)
                .padding(.top, 12)
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
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "E6E6EC"))
                                .frame(width: 50, height: 70)
                        }

                        Text("Page \(item.originalIndex + 1)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "1D1D1D"))
                            .tracking(-0.408)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(hex: "888888").opacity(0.12))
                            .frame(height: 1)
                            .padding(.leading, 78)
                    }
                }
                .onMove { from, to in
                    pageItems.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))

            // Apply button
            Button {
                let order = pageItems.map { $0.originalIndex }
                onReorder(fileURL!, fileName, order)
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
                                    colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
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

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Text("Reorder pages")
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

    // MARK: - File Import

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
