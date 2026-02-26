import SwiftUI
import UniformTypeIdentifiers

struct PDFMergeView: View {
    let onMerge: ([URL], [String]) -> Void

    @State private var fileURLs: [URL] = []
    @State private var fileNames: [String] = []
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            if fileURLs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Add PDF files to merge")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Files will be merged in the order shown")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                List {
                    ForEach(Array(fileNames.enumerated()), id: \.offset) { index, name in
                        HStack {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(.red)
                            Text(name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onMove { from, to in
                        fileNames.move(fromOffsets: from, toOffset: to)
                        fileURLs.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { offsets in
                        fileNames.remove(atOffsets: offsets)
                        fileURLs.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            }

            VStack(spacing: 12) {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Add PDFs", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                if fileURLs.count >= 2 {
                    Button {
                        onMerge(fileURLs, fileNames)
                    } label: {
                        Text("Merge \(fileURLs.count) PDFs")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .navigationTitle("Merge PDFs")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for sourceURL in urls {
            guard sourceURL.startAccessingSecurityScopedResource() else { continue }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            let fileName = sourceURL.lastPathComponent
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("rango_pdf_merge", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let shortID = UUID().uuidString.prefix(8)
            let destURL = tempDir.appendingPathComponent("\(shortID)_\(fileName)")
            try? FileManager.default.removeItem(at: destURL)

            if let _ = try? FileManager.default.copyItem(at: sourceURL, to: destURL) {
                fileURLs.append(destURL)
                fileNames.append(fileName)
            }
        }
    }
}
