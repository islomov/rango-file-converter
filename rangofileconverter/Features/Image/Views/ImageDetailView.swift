import SwiftUI

struct ImageDetailView: View {
    let fileURL: URL
    let fileName: String
    let onConvert: (FormatDefinition) async -> Void

    @State private var previewImage: UIImage?
    @State private var targetFormat: FormatDefinition = FormatRegistry.imageFormats[1] // JPEG
    @State private var isConverting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                } else {
                    ProgressView()
                        .frame(height: 350)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(fileName)
                        .font(.headline)
                    Text(formattedFileSize)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Convert to")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(FormatRegistry.imageFormats) { format in
                            Button(format.displayName) {
                                targetFormat = format
                            }
                            .buttonStyle(.bordered)
                            .tint(targetFormat.id == format.id ? .accentColor : .secondary)
                        }
                    }
                }

                Button {
                    isConverting = true
                    Task {
                        await onConvert(targetFormat)
                        isConverting = false
                        dismiss()
                    }
                } label: {
                    if isConverting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Convert")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConverting)
            }
            .padding(20)
        }
        .navigationTitle("Convert Image")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            previewImage = ImageConverterViewModel.loadPreviewImage(from: fileURL)
        }
    }

    private var formattedFileSize: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
