import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerConfig {
    let navTitle: String
    let icon: String
    let heading: String
    let subtitle: String
    let buttonTitle: String
    let allowedTypes: [UTType]
    let allowsMultipleSelection: Bool

    static let convert = DocumentPickerConfig(
        navTitle: "Convert",
        icon: "icon_doc_convert",
        heading: "Select a document to convert",
        subtitle: "Supported: DOC, DOCX, PDF, HTML, ODT, RTF, TXT",
        buttonTitle: "Choose file",
        allowedTypes: [
            .pdf, .plainText, .rtf, .html,
            UTType("com.microsoft.word.doc") ?? .data,
            UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
            UTType("org.oasis-open.opendocument.text") ?? .data,
        ],
        allowsMultipleSelection: false
    )

    static let mergePDF = DocumentPickerConfig(
        navTitle: "Merge PDF",
        icon: "icon_doc_merge",
        heading: "Add PDF files to merge",
        subtitle: "Files will be merged in the order shown",
        buttonTitle: "Add PDFs",
        allowedTypes: [.pdf],
        allowsMultipleSelection: true
    )

    static let splitPDF = DocumentPickerConfig(
        navTitle: "Split PDF",
        icon: "icon_doc_split",
        heading: "Select a PDF to split",
        subtitle: "",
        buttonTitle: "Choose PDF",
        allowedTypes: [.pdf],
        allowsMultipleSelection: false
    )

    static let reorderPDF = DocumentPickerConfig(
        navTitle: "Reorder pages",
        icon: "icon_doc_reorder",
        heading: "Select a PDF to reorder pages",
        subtitle: "",
        buttonTitle: "Choose PDF",
        allowedTypes: [.pdf],
        allowsMultipleSelection: false
    )

    static let protectPDF = DocumentPickerConfig(
        navTitle: "Protect PDF",
        icon: "icon_doc_protect",
        heading: "Select a PDF to protect",
        subtitle: "",
        buttonTitle: "Choose PDF",
        allowedTypes: [.pdf],
        allowsMultipleSelection: false
    )
}

struct DocumentPickerView: View {
    let config: DocumentPickerConfig
    let onDocumentsSelected: ([(String, URL)]) -> Void

    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    init(
        config: DocumentPickerConfig = .convert,
        onDocumentSelected: @escaping (String, URL) -> Void
    ) {
        self.config = config
        self.onDocumentsSelected = { files in
            if let first = files.first {
                onDocumentSelected(first.0, first.1)
            }
        }
    }

    init(
        config: DocumentPickerConfig,
        onDocumentsSelected: @escaping ([(String, URL)]) -> Void
    ) {
        self.config = config
        self.onDocumentsSelected = onDocumentsSelected
    }

    var body: some View {
        ZStack {
            Color(hex: "F2F2F6")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                Spacer()
                pickerContent
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: config.allowedTypes,
            allowsMultipleSelection: config.allowsMultipleSelection
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Text(config.navTitle)
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

    // MARK: - Picker Content

    private var pickerContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(config.icon)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 56, height: 56)

                VStack(spacing: 8) {
                    Text(config.heading)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .tracking(-0.408)
                        .multilineTextAlignment(.center)

                    if !config.subtitle.isEmpty {
                        Text(config.subtitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                            .tracking(-0.408)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            Button {
                showFilePicker = true
            } label: {
                Text(config.buttonTitle)
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
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_doc_import", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var imported: [(String, URL)] = []

        for sourceURL in urls {
            guard sourceURL.startAccessingSecurityScopedResource() else { continue }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            let fileName = sourceURL.lastPathComponent
            let shortID = UUID().uuidString.prefix(8)
            let destURL = tempDir.appendingPathComponent("\(shortID)_\(fileName)")
            try? FileManager.default.removeItem(at: destURL)

            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                imported.append((fileName, destURL))
            } catch {
                // File copy failed silently
            }
        }

        if !imported.isEmpty {
            onDocumentsSelected(imported)
        }
    }
}
