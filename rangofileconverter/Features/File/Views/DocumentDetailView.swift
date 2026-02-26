import SwiftUI

struct DocumentDetailView: View {
    let fileName: String
    let fileURL: URL
    let onConvert: (FormatDefinition) -> Void

    private static let supportedFormats = FormatRegistry.documentFormats

    @State private var targetFormat: FormatDefinition = FormatRegistry.documentFormats[0]
    @State private var fileSizeText: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Document icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .frame(height: 200)

                    VStack(spacing: 12) {
                        Image(systemName: documentIcon)
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text(sourceExtension.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.secondary, in: Capsule())
                    }
                }

                // Internet required notice
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .font(.caption)
                    Text("Requires internet connection")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())

                // File info
                VStack(alignment: .leading, spacing: 8) {
                    Text(fileName)
                        .font(.headline)
                    Text(fileSizeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Format selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Convert to")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(availableFormats) { format in
                            Button(format.displayName) {
                                targetFormat = format
                            }
                            .buttonStyle(.bordered)
                            .tint(targetFormat.id == format.id ? .accentColor : .secondary)
                        }
                    }
                }

                // Convert button
                Button {
                    onConvert(targetFormat)
                } label: {
                    Text("Convert")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .navigationTitle("Document Conversion")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let path = fileURL.path
            let size = await Task.detached(priority: .utility) {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let bytes = attrs[.size] as? Int64 else { return "" }
                return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }.value
            fileSizeText = size
        }
        .onAppear {
            // Default to first format that isn't the source format
            if let first = availableFormats.first {
                targetFormat = first
            }
        }
    }

    private var availableFormats: [FormatDefinition] {
        Self.supportedFormats.filter { $0.fileExtension.lowercased() != sourceExtension.lowercased() }
    }

    private var sourceExtension: String {
        fileName.components(separatedBy: ".").last ?? ""
    }

    private var documentIcon: String {
        switch sourceExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "html": return "globe"
        case "rtf": return "doc.richtext"
        case "txt": return "doc.plaintext"
        case "odt": return "doc.text"
        default: return "doc"
        }
    }
}
