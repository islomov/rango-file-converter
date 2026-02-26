import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: View {
    let onDocumentSelected: (String, URL) -> Void

    @State private var showFilePicker = false

    private static let allowedTypes: [UTType] = [
        .pdf,
        .plainText,
        .rtf,
        .html,
        UTType("com.microsoft.word.doc") ?? .data,
        UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
        UTType("org.oasis-open.opendocument.text") ?? .data,
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Select a document to convert")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Supported: DOC, DOCX, PDF, HTML, ODT, RTF, TXT")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                showFilePicker = true
            } label: {
                Label("Choose File", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer()
        }
        .navigationTitle("Select Document")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: Self.allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let fileName = sourceURL.lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_doc_import", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destURL)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            onDocumentSelected(fileName, destURL)
        } catch {
            // File copy failed silently
        }
    }
}
